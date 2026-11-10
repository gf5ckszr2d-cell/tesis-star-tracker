#include "xparameters.h"
#include "xuartps.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_io.h"
#include "sty1.h"
#include "xgpiops_hw.h"
#define UART_PC XPAR_XUARTPS_0_BASEADDR
#define UART_FPGA XPAR_XUARTPS_1_BASEADDR
/* SDT encodes SPI index/trigger; XScuGic uses absolute GIC ID (82). */
#define UART_IRQ ((XPAR_XUARTPS_1_INTERRUPTS & 0xFFFU) + 32U)
#define TIMER_LOW 0xF8F00200U
#define TIMER_HIGH 0xF8F00204U
#define TIMER_CTRL 0xF8F00208U
#define RING_SIZE 65536U
#define RING_MASK (RING_SIZE - 1U)
#define RX_ERRORS (XUARTPS_IXR_OVER | XUARTPS_IXR_FRAMING | XUARTPS_IXR_PARITY)
#define RX_IRQS (RX_ERRORS | XUARTPS_IXR_RXOVR | XUARTPS_IXR_TOUT)
static XUartPs uart_pc, uart_fpga;
static XScuGic gic;
static volatile u8 ring[RING_SIZE];
static volatile u32 head, tail, rx_fault;
static Sty1 packet;
static u64 ticks_per_ms;
static u64 last_capture_status;
static void numero(u32 value)
{
    char digits[10]; unsigned used=0;
    do { digits[used++] = (char)('0' + value%10U); value/=10U; } while (value);
    while (used) XUartPs_SendByte(UART_PC, (u8)digits[--used]);
}
static u64 timer_now(void)
{
    u32 hi, lo;
    do {
        hi = Xil_In32(TIMER_HIGH); lo = Xil_In32(TIMER_LOW);
    } while (hi != Xil_In32(TIMER_HIGH));
    return ((u64)hi << 32) | lo;
}
static void texto(const char *s)
{
    while (*s) XUartPs_SendByte(UART_PC, (u8)*s++);
}
static void diagnostico_captura(void)
{
    const UINTPTR base = XPAR_XGPIOPS_0_BASEADDR;
    u32 hi = Xil_In32(base + XGPIOPS_DATA_RO_OFFSET + 12U);
    u32 lo = Xil_In32(base + XGPIOPS_DATA_RO_OFFSET + 8U);
    u64 value;
    static const char *reason[] = {"OK", "LINEA_CORTA", "LINEA_LARGA", "BYTES_IMPARES",
        "FALTAN_LINEAS", "SOBRAN_LINEAS", "CUENTA_PIXELES", "ORDEN_BRAM", "OVERFLOW_CAPTURA"};
    /* Snapshot is latched in PL until next frame. Reject any changing read. */
    if (hi != Xil_In32(base + XGPIOPS_DATA_RO_OFFSET + 12U) ||
        lo != Xil_In32(base + XGPIOPS_DATA_RO_OFFSET + 8U)) return;
    value = ((u64)hi << 32) | lo;
    if (!(hi & 0x80000000U)) { last_capture_status=0; return; }
    if (value == last_capture_status) return;
    last_capture_status = value;
    texto("\r\nARM captura: ");
    texto((lo & 15U) < 9U ? reason[lo & 15U] : "CONTADOR_SATURADO");
    texto(" lineas="); numero((lo >> 4) & 255U);
    texto(" bytes_min="); numero(((lo >> 4) & 255U) ? ((lo >> 12) & 2047U) : 0U);
    texto(" bytes_max="); numero((u32)(value >> 24) & 4095U);
    texto(" pixeles="); numero(((u32)(value >> 36) & 65535U) | (((lo >> 23) & 1U) << 16));
    texto(" primera_linea_mala=");
    if (((value >> 52) & 255U)==255U) texto("ninguna");
    else numero((u32)(value >> 52) & 255U);
    texto("\r\n");
}
static void uart_rx_irq(void *unused)
{
    u32 pending;
    (void)unused;
    pending = XUartPs_ReadReg(UART_FPGA, XUARTPS_ISR_OFFSET);
    /* Clear before draining: a new event while draining remains pending. */
    XUartPs_WriteReg(UART_FPGA, XUARTPS_ISR_OFFSET, pending);
    if (pending & RX_ERRORS) rx_fault = 1;
    while (XUartPs_IsReceiveData(UART_FPGA)) {
        u8 b = (u8)XUartPs_ReadReg(UART_FPGA, XUARTPS_FIFO_OFFSET);
        u32 next = (head + 1U) & RING_MASK;
        if (next == tail) rx_fault = 1;
        else {
            ring[head] = b;
            __asm__ volatile ("dmb sy" ::: "memory");
            head = next;
        }
    }
    if (pending & XUARTPS_IXR_TOUT)
        XUartPs_WriteReg(UART_FPGA, XUARTPS_CR_OFFSET,
            XUartPs_ReadReg(UART_FPGA, XUARTPS_CR_OFFSET) | XUARTPS_CR_TORST);
}
static int configurar_uart(XUartPs *u, UINTPTR base, u32 baud)
{
    XUartPs_Config *cfg = XUartPs_LookupConfig(base);
    XUartPsFormat format = { baud, XUARTPS_FORMAT_8_BITS,
        XUARTPS_FORMAT_NO_PARITY, XUARTPS_FORMAT_1_STOP_BIT };
    if (!cfg || XUartPs_CfgInitialize(u, cfg, base) != XST_SUCCESS) return XST_FAILURE;
    XUartPs_SetInterruptMask(u, 0);
    XUartPs_SetOperMode(u, XUARTPS_OPER_MODE_NORMAL);
    return XUartPs_SetDataFormat(u, &format);
}
static int configurar_irq(void)
{
    XScuGic_Config *cfg = XScuGic_LookupConfig(XPAR_XSCUGIC_0_BASEADDR);
    if (!cfg || XScuGic_CfgInitialize(&gic, cfg, cfg->CpuBaseAddress) != XST_SUCCESS)
        return XST_FAILURE;
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XScuGic_InterruptHandler, &gic);
    if (XScuGic_Connect(&gic, UART_IRQ, uart_rx_irq, 0) != XST_SUCCESS) return XST_FAILURE;
    XScuGic_SetPriorityTriggerType(&gic, UART_IRQ, 0xA0, 1);
    XUartPs_SetFifoThreshold(&uart_fpga, 16);
    XUartPs_SetRecvTimeout(&uart_fpga, 8);
    XUartPs_WriteReg(UART_FPGA, XUARTPS_ISR_OFFSET, XUARTPS_IXR_MASK);
    XScuGic_Enable(&gic, UART_IRQ);
    XUartPs_SetInterruptMask(&uart_fpga, RX_IRQS);
    Xil_ExceptionEnable();
    return XST_SUCCESS;
}
int main(void)
{
    u64 last_byte, frame_start = 0, last_diag = 0, trigger_end = 0;
    u32 timer_ctrl = Xil_In32(TIMER_CTRL);
    Xil_Out32(TIMER_CTRL, timer_ctrl | 1U);
    /* CPU/2 divided by the existing 8-bit global-timer prescaler. */
    ticks_per_ms = (u64)XPAR_CPU_CORE_CLOCK_FREQ_HZ /
        (2U * (((timer_ctrl >> 8) & 255U) + 1U) * 1000U);
    if (configurar_uart(&uart_pc, UART_PC, 115200) != XST_SUCCESS) return XST_FAILURE;
    texto("\r\nARM iniciado; imagen 320x240; UART1=921600 UART0=115200\r\n");
    if (configurar_uart(&uart_fpga, UART_FPGA, 921600) != XST_SUCCESS ||
        configurar_irq() != XST_SUCCESS) {
        texto("ERROR configuracion UART1/GIC\r\n"); return XST_FAILURE;
    }
    last_byte = timer_now();
    /* EMIO inputs carry status. Output bit 0 pulses the debounced start path.
       GPIO_I is separately wired to PL status, with no external I/O buffer. */
    Xil_Out32(XPAR_XGPIOPS_0_BASEADDR + XGPIOPS_DATA_OFFSET + 8U, 0);
    Xil_Out32(XPAR_XGPIOPS_0_BASEADDR + XGPIOPS_DIRM_OFFSET + 2U*0x40U, 1);
    Xil_Out32(XPAR_XGPIOPS_0_BASEADDR + XGPIOPS_OUTEN_OFFSET + 2U*0x40U, 1);
    Xil_Out32(XPAR_XGPIOPS_0_BASEADDR + XGPIOPS_DIRM_OFFSET + 3U*0x40U, 0);
    Xil_Out32(XPAR_XGPIOPS_0_BASEADDR + XGPIOPS_OUTEN_OFFSET + 3U*0x40U, 0);
    texto("Receptor OV7670 listo; esperando BTN1\r\n");
    for (;;) {
        u64 now = timer_now();
        if (trigger_end && now >= trigger_end) {
            Xil_Out32(XPAR_XGPIOPS_0_BASEADDR + XGPIOPS_DATA_OFFSET + 8U, 0);
            trigger_end=0;
        }
        if (XUartPs_IsReceiveData(UART_PC)) {
            u8 command=(u8)XUartPs_ReadReg(UART_PC, XUARTPS_FIFO_OFFSET);
            if ((command=='c' || command=='C') && !trigger_end) {
                Xil_Out32(XPAR_XGPIOPS_0_BASEADDR + XGPIOPS_DATA_OFFSET + 8U, 1);
                trigger_end=now+30U*ticks_per_ms;
                texto("ARM solicitud de captura por COM3\r\n");
            }
        }
        if (now-last_diag > 10U*ticks_per_ms) {
            diagnostico_captura(); last_diag=now;
        }
        if (rx_fault) {
            Xil_ExceptionDisable(); tail = head; rx_fault = 0; Xil_ExceptionEnable();
            sty1_reset(&packet);
            texto("ERROR UART1: framing/paridad/overflow; trama descartada\r\n");
        }
        if (head != tail) {
            u8 b;
            int result;
            __asm__ volatile ("dmb sy" ::: "memory");
            b = ring[tail];
            __asm__ volatile ("dmb sy" ::: "memory");
            tail = (tail + 1U) & RING_MASK;
            if (!packet.used) frame_start = now;
            result = sty1_feed(&packet, b); last_byte = now;
            if (result == 1) {
                if (rx_fault) continue; /* do not forward a packet affected by a UART fault */
                /* ISR continues receiving into RAM while UART0 sends. */
                for (u32 i = 0; i < STY1_SIZE; ++i)
                    XUartPs_SendByte(UART_PC, packet.bytes[i]);
                texto("\r\nOK imagen 76800 checksum; esperando BTN1\r\n");
            } else if (result == -1) texto("ERROR cabecera de imagen\r\n");
            else if (result == -2) texto("ERROR checksum de imagen\r\n");
        } else if (packet.used && ((now - last_byte > 100U * ticks_per_ms) ||
             (now - frame_start > 2000U * ticks_per_ms))) {
            sty1_reset(&packet); texto("ERROR timeout: trama de imagen incompleta\r\n");
        }
    }
}

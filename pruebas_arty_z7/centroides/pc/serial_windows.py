"""Small synchronous Win32 COM adapter; Python standard library only."""
import ctypes as C
from ctypes import wintypes as W
import winreg

class DCB(C.Structure):
    _fields_ = [('DCBlength', W.DWORD), ('BaudRate', W.DWORD), ('flags', W.DWORD),
                ('wReserved', W.WORD), ('XonLim', W.WORD), ('XoffLim', W.WORD),
                ('ByteSize', W.BYTE), ('Parity', W.BYTE), ('StopBits', W.BYTE),
                ('XonChar', C.c_char), ('XoffChar', C.c_char), ('ErrorChar', C.c_char),
                ('EofChar', C.c_char), ('EvtChar', C.c_char), ('wReserved1', W.WORD)]
class Timeouts(C.Structure):
    _fields_ = [(name, W.DWORD) for name in ('interval', 'read_multiplier', 'read_constant',
                                           'write_multiplier', 'write_constant')]

def ports():
    result = []
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r'HARDWARE\DEVICEMAP\SERIALCOMM') as key:
            for i in range(winreg.QueryInfoKey(key)[1]):
                name, value, _ = winreg.EnumValue(key, i)
                result.append({'port': value, 'device': name})
    except FileNotFoundError:
        pass
    return result

class Serial:
    def __init__(self, port, baud=115200):
        self.api = C.WinDLL('kernel32', use_last_error=True)
        self.api.CreateFileW.argtypes = [W.LPCWSTR, W.DWORD, W.DWORD, C.c_void_p,
                                         W.DWORD, W.DWORD, W.HANDLE]
        self.api.CreateFileW.restype = W.HANDLE
        for name in ('GetCommState', 'SetCommState', 'SetCommTimeouts'):
            getattr(self.api, name).argtypes = [W.HANDLE, C.c_void_p]
        self.api.SetupComm.argtypes = [W.HANDLE, W.DWORD, W.DWORD]
        for name in ('ReadFile', 'WriteFile'):
            getattr(self.api, name).argtypes = [W.HANDLE, C.c_void_p, W.DWORD,
                                               C.POINTER(W.DWORD), C.c_void_p]
        self.api.CloseHandle.argtypes = [W.HANDLE]
        self.handle = self.api.CreateFileW('\\\\.\\' + port, 0xc0000000, 0,
                                           None, 3, 0x80, None)
        if self.handle == C.c_void_p(-1).value:
            self.handle = None
            raise C.WinError(C.get_last_error())
        try:
            dcb = DCB(); dcb.DCBlength = C.sizeof(DCB)
            self._check(self.api.GetCommState(self.handle, C.byref(dcb)))
            dcb.BaudRate, dcb.flags = baud, 1  # binary; no flow control, DTR or RTS
            dcb.ByteSize, dcb.Parity, dcb.StopBits = 8, 0, 0
            self._check(self.api.SetCommState(self.handle, C.byref(dcb)))
            timeout = Timeouts(50, 0, 100, 0, 1000)
            self._check(self.api.SetCommTimeouts(self.handle, C.byref(timeout)))
            self._check(self.api.SetupComm(self.handle, 262144, 4096))
        except BaseException:
            self.close(); raise
    @staticmethod
    def _check(result):
        if not result:
            raise C.WinError(C.get_last_error())
    def read(self, size=4096):
        buffer = C.create_string_buffer(size); used = W.DWORD()
        self._check(self.api.ReadFile(self.handle, buffer, size, C.byref(used), None))
        return buffer.raw[:used.value]
    def write(self, data):
        buffer = C.create_string_buffer(data); used = W.DWORD()
        self._check(self.api.WriteFile(self.handle, buffer, len(data), C.byref(used), None))
        if used.value != len(data):
            raise OSError('Escritura COM incompleta')
    def close(self):
        if self.handle is not None:
            self.api.CloseHandle(self.handle); self.handle = None
    def __enter__(self): return self
    def __exit__(self, *args): self.close()

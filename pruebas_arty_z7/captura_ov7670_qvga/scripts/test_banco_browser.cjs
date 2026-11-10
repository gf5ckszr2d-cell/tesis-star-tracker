// Run against pc/browser_ui_fixture.py only. Never starts a camera capture.
const fs = require('node:fs/promises');
const path = require('node:path');
const {chromium} = require(path.join(process.argv[2], 'playwright'));
const root = path.resolve(__dirname,'..');
(async()=>{
  const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  try {
    const errors=[];
    const context=await browser.newContext({viewport:{width:1366,height:1000}});
    const page=await context.newPage(); page.on('pageerror',e=>errors.push(e.message));
    await page.goto('http://127.0.0.1:8766/');
    await page.waitForSelector('.card');
    if(await page.locator('.card').count()!==30) throw Error('Expected 30 cards');
    await page.screenshot({path:path.join(root,'build/banco_doe_operator_ui.png')});
    const invalid=page.waitForResponse(r=>r.url().endsWith('/api/visual'));
    await page.locator('#submit').click();
    if((await invalid).status()!==400) throw Error('Incomplete visual form accepted');
    await page.locator('.card select').evaluateAll(selects=>selects.forEach(s=>s.value='yes'));
    await page.locator('#selected').selectOption('C01');
    await page.locator('#reason').fill('SYNTHETIC_BROWSER_QA: no physical operator decision');
    const valid=page.waitForResponse(r=>r.url().endsWith('/api/visual'));
    await page.locator('#submit').click();
    if((await valid).status()!==200) throw Error('Complete visual form rejected');
    const display=await browser.newContext({viewport:{width:2560,height:1440},screen:{width:2560,height:1440}});
    const stimulus=await display.newPage(); stimulus.on('pageerror',e=>errors.push(e.message));
    await stimulus.goto('http://127.0.0.1:8766/patron');
    await stimulus.getByRole('button').click();
    await stimulus.waitForFunction(()=>!!document.fullscreenElement);
    await stimulus.waitForTimeout(1200);
    const result=await stimulus.evaluate(()=>({width:innerWidth,height:innerHeight,dpr:devicePixelRatio,fullscreen:!!document.fullscreenElement,visible:!document.hidden,
      center:Array.from(document.querySelector('canvas').getContext('2d').getImageData(1280,720,1,1).data)}));
    if(result.center[0]!==255 || result.width!==2560 || result.height!==1440) throw Error('Stimulus rendering mismatch');
    await stimulus.screenshot({path:path.join(root,'build/banco_doe_stimulus_ui.png')});
    if(errors.length) throw Error(errors.join('; '));
    const report={result:'PASS_BROWSER_DOE',synthetic_only:true,visual_cards:30,incomplete_form_rejected:true,complete_form_accepted:true,display:result,javascript_errors:errors};
    await fs.writeFile(path.join(root,'build/banco_doe_browser_test.json'),JSON.stringify(report,null,2));
    console.log(JSON.stringify(report));
  }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});

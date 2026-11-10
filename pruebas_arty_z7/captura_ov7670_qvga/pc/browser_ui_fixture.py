"""Temporary browser QA fixture, no serial connection or hardware access. Run as a script."""
from http.server import ThreadingHTTPServer
import io
from pathlib import Path
import tempfile
from banco_doe import Bench, ROOT, pattern, CENTER, make_handler

with tempfile.TemporaryDirectory(prefix='SYNTHETIC_UI_',dir=ROOT/'build') as tmp:
    bench=Bench(Path(tmp)/'data','FAKE',physical=False)
    image,meta=pattern(points=[CENTER],diameter=8)
    stream=io.BytesIO(); image.save(stream,format='PNG'); bench.png=stream.getvalue()
    bench.state['scene']=dict(id='synthetic_scene',name='SYNTHETIC_ONLY',**meta)
    directory=bench.output/'images'; directory.mkdir()
    for i in range(30):
        identity=f'SYNTHETIC_C{i//5+1:02d}_{i%5+1:02d}'
        picture=image.crop((1040,540,1520,900)).resize((320,240))
        picture.save(directory/f'{identity}.png')
        row=dict(id=identity,condition=f'C{i//5+1:02d}',image=f'images/{identity}.png',exposure=100,gain=0,
                 statistics={'max':200})
        bench.state['visual_images'].append(row); bench.d1.append(row)
    bench.state.update(phase='CRITERIO_VISUAL_D1',message='SYNTHETIC BROWSER TEST',rows=30)
    server=ThreadingHTTPServer(('127.0.0.1',8766),make_handler(bench))
    print('SYNTHETIC_UI_READY',flush=True)
    server.serve_forever()

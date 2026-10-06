"""Build the single-thread Godot Web edition using its project-local official template."""
from pathlib import Path
import subprocess,os,json,hashlib,shutil
root=Path(__file__).resolve().parent.parent
project=root/'godot';out=root/'dist';template=root/'tools/web_nothreads_release.zip'
if not template.is_file():raise SystemExit('Run python3 tools/fetch_web_template.py --extract first.')
out.mkdir(exist_ok=True)
env=os.environ.copy()
# Keep the existing environment's explicit XDG values, or use a local build cache.
for suffix in ['DATA','CACHE','CONFIG']:
 key='XDG_'+suffix+'_HOME'
 if key not in env:env[key]=str(root/'.build-xdg'/suffix.lower())
 Path(env[key]).mkdir(parents=True,exist_ok=True)
subprocess.run(['godot','--headless','--path',str(project),'--editor','--import'],env=env,check=True,timeout=90)
subprocess.run(['godot','--headless','--path',str(project),'--export-release','Web',str(out/'index.html')],env=env,check=True,timeout=90)
for name in ['shell.css','shell.js','LICENSES.txt']:shutil.copy2(project/'web'/name,out/name)
(out/'.nojekyll').write_text('')
files={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(out.iterdir()) if p.is_file() and p.name!='build-manifest.json'}
manifest={'gameplay_version':'0.8.1','engine':'4.6.3','thread_support':False,'renderer':'gl_compatibility','files':files}
(out/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('WEB_BUILD_COMPLETE',out,'bytes',sum(x['bytes'] for x in files.values()))

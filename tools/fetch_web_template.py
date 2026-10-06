"""Read the official ZIP directory and extract only its non-threaded Web release member."""
from pathlib import Path
import urllib.request,struct,json,hashlib,zlib,io,zipfile,sys
URL='https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz'
SIZE=1255918323
ARCHIVE_SHA256='3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8'
OUT=Path(__file__).resolve().parent

def get_range(a,b):
 assert 0<=a<=b<SIZE
 req=urllib.request.Request(URL,headers={'Range':f'bytes={a}-{b}','Accept-Encoding':'identity','User-Agent':'Emberwake-build-template-fetch'})
 with urllib.request.urlopen(req,timeout=45) as response:
  if response.status!=206 or response.headers.get('Content-Range')!=f'bytes {a}-{b}/{SIZE}':raise RuntimeError('Server did not honor exact byte range; full download was not consumed')
  data=response.read(b-a+2)
  if len(data)!=b-a+1:raise RuntimeError('Unexpected byte count')
  return data

tail=get_range(SIZE-65557,SIZE-1);at=tail.rfind(b'PK\x05\x06');assert at>=0
end=struct.unpack_from('<4s4H2IH',tail,at)
assert end[1]==0 and end[2]==0 and end[3]==end[4] and end[4]!=65535
central=get_range(end[6],end[6]+end[5]-1);entries=[];pos=0
while pos<len(central):
 v=struct.unpack_from('<4s6H3I5H2I',central,pos);assert v[0]==b'PK\x01\x02'
 name=central[pos+46:pos+46+v[10]].decode('utf-8' if v[3]&0x800 else 'cp437')
 entries.append({'name':name,'flags':v[3],'method':v[4],'crc32':v[7],'compressed_bytes':v[8],'bytes':v[9],'local_offset':v[16]})
 pos+=46+v[10]+v[11]+v[12]
assert len(entries)==end[4]
web=[e for e in entries if 'web' in e['name']]
(OUT/'official_template_members.json').write_text(json.dumps(web,indent=2)+'\n')
print(json.dumps(web,indent=2),flush=True)
if '--extract' not in sys.argv:sys.exit(0)
chosen=[e for e in web if e['name']=='templates/web_nothreads_release.zip'];assert len(chosen)==1
entry=chosen[0];assert not entry['flags']&1 and entry['method'] in (0,8) and entry['bytes']<120_000_000 and entry['compressed_bytes']<120_000_000
header=get_range(entry['local_offset'],entry['local_offset']+29);v=struct.unpack('<4s5H3I2H',header);assert v[0]==b'PK\x03\x04' and v[3]==entry['method']
name=get_range(entry['local_offset']+30,entry['local_offset']+29+v[9]);assert name.decode()==entry['name']
start=entry['local_offset']+30+v[9]+v[10]
compressed=get_range(start,start+entry['compressed_bytes']-1)
data=zlib.decompress(compressed,-15) if entry['method']==8 else compressed
assert len(data)==entry['bytes'] and zlib.crc32(data)&0xffffffff==entry['crc32']
with zipfile.ZipFile(io.BytesIO(data)) as inner:
 assert inner.testzip() is None
 members=[{'name':i.filename,'bytes':i.file_size,'crc32':i.CRC} for i in inner.infolist()]
 assert any(x['name'].endswith('.wasm') for x in members)
output=OUT/'web_nothreads_release.zip';output.write_bytes(data)
record={'official_url':URL,'release':'4.6.3-stable','official_full_archive_bytes':SIZE,'official_full_archive_sha256_reference':ARCHIVE_SHA256,'full_archive_sha256_verified':False,'verification':'HTTPS official release; exact Content-Range and size; outer member CRC32; complete inner ZIP CRC verification','member':entry,'member_sha256':hashlib.sha256(data).hexdigest(),'inner_members':members}
(OUT/'web_template_provenance.json').write_text(json.dumps(record,indent=2)+'\n')
print('TEMPLATE_READY',output,'bytes',len(data),'sha256',record['member_sha256'],flush=True)
print('INNER_MEMBERS',json.dumps(members),flush=True)

"""Fetch only desktop entries from the official 4.7.2 TPZ via HTTP ranges."""
import io,struct,subprocess,zlib,time
from pathlib import Path
URL='https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
TOTAL=1281349702
DEST=Path(__file__).resolve().parents[1]/'.build-tools'/'templates'
DEST.mkdir(parents=True,exist_ok=True)
def read(start,count):
 for attempt in range(4):
  try:
   result=subprocess.run(['curl','-fsSL','--max-time','60','--max-filesize',str(count),'--range',f'{start}-{start+count-1}',URL],check=True,capture_output=True)
   data=result.stdout
   if len(data)!=count:raise ValueError('Truncated archive range')
   return data
  except Exception:
   if attempt==3:raise
   time.sleep(1)
tail=read(TOTAL-65536,65536);eocd=tail.rfind(b'PK\x05\x06')
assert eocd>=0,'Missing ZIP end record'
_,_,_,_,entries,size,offset,_=struct.unpack_from('<4s4H2LH',tail,eocd)
central=read(offset,size);cursor=0;selected=[]
for i in range(entries):
 header=struct.unpack_from('<4s6H3L5H2L',central,cursor)
 assert header[0]==b'PK\x01\x02'
 name=central[cursor+46:cursor+46+header[10]].decode()
 if name in ['templates/macos.zip','templates/windows_release_x86_64.exe','templates/windows_debug_x86_64.exe']:
  selected.append((name,header[4],header[7],header[8],header[9],header[16]))
 cursor+=46+header[10]+header[11]+header[12]
assert len(selected)==3,selected
for name,method,crc,compressed,uncompressed,local in selected:
 destination=DEST/Path(name).name
 if destination.exists() and destination.stat().st_size==uncompressed and zlib.crc32(destination.read_bytes())==crc:
  print('Verified existing',destination.name,flush=True);continue
 header=read(local,30);values=struct.unpack('<4s5H3L2H',header)
 assert values[0]==b'PK\x03\x04'
 position=local+30+values[-2]+values[-1]
 blocks=[]
 for consumed in range(0,compressed,8*1024*1024):
  count=min(8*1024*1024,compressed-consumed);blocks.append(read(position+consumed,count))
  print(name,consumed+count,'/',compressed,flush=True)
 packed=b''.join(blocks)
 data=zlib.decompress(packed,-15) if method==8 else packed
 assert len(data)==uncompressed and zlib.crc32(data)==crc,'Template CRC mismatch'
 temporary=destination.with_suffix(destination.suffix+'.tmp');temporary.write_bytes(data);temporary.replace(destination)
 print('CRC verified',destination.name,len(data),flush=True)

import time
import subprocess

server_proc = subprocess.Popen(["odin", "run", "test_server.odin", "-file"])
client_proc = subprocess.Popen(["odin", "run", "test_client.odin", "-file"])

time.sleep(3)

rc: int | None = server_proc.wait()
if rc != 0:
    print('server exited wrongly', rc)
rc: int | None = client_proc.wait()
if rc != 0:
    print('client exited wrongly', rc)


print('good')




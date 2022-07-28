import time
import subprocess

def print_exit(who: str, exit: int | None):
    if exit != 0:
        print(who, 'exited wrongly', exit)


server_proc = subprocess.Popen(["odin", "run", "test_server.odin", "-file"])
time.sleep(1)
client_proc = subprocess.Popen(["odin", "run", "test_client.odin", "-file"])

print_exit('server', server_proc.wait())
print_exit('client', client_proc.wait())

server_proc = subprocess.Popen(["odin", "run", "test_server2.odin", "-file"])
time.sleep(1)
client_proc = subprocess.Popen(["odin", "run", "test_client.odin", "-file"])

print_exit('server', server_proc.wait())
print_exit('client', client_proc.wait())



print('good')




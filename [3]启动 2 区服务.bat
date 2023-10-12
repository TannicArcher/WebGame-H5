cd "D:\LT_Server\bin\s2\dbserver"
start DBServer64_debug.exe
ping localhost -n 2
cd "D:\LT_Server\bin\s2\gameworld"
start GameWorld64_debug.exe
ping localhost -n 2
cd "D:\LT_Server\bin\s2\gateway"
start Gateway64_debug.exe
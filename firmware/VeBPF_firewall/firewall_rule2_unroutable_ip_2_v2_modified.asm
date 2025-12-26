mov32 r1, 12
ldxh r4, [r1]
be16 r4
jeq r4, 0x0800, +2
mov r0, 0x01	
exit
mov32 r1, 26
ldxw r4, [r1]
be32 r4
jeq r4, 0x80000000, +2
mov r0, 0x01  
exit
mov r0, 0x03  
exit
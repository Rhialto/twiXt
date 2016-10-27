# Makefile for the Joystick test widget

XDIR=/usr/X11R7
CFLAGS += -I${XDIR}/include -I${XDIR}/include/X11/Xaw -I.
LDFLAGS += -L${XDIR}/lib -Wl,-R${XDIR}/lib -lXaw -lXt

joystick:	Joystick.o main.o
	${CC} -o joystick Joystick.o main.o ${LDFLAGS}

Joystick.o:	Joystick.c
	${CC} -c ${CFLAGS} Joystick.c -o Joystick.o

main.o:
	${CC} -c ${CFLAGS} main.c -o main.o

Joystick.c:	Joystick.xt
	../twixt Joystick.xt

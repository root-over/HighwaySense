COMPONENT=TelosbAppC
PFLAGS += -DCC2420_DEF_CHANNEL=16
CFLAGS += -I$(TOSDIR)/chips/msp430/usart
CFLAGS += -I$(TOSDIR)/lib/printf
include $(MAKERULES)

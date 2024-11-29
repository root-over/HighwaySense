configuration MacchinaAppC{
}

implementation {
	components MacchinaC, MainC, LedsC;
	components new TimerMilliC() as TimerC1;
	components new TimerMilliC() as TimerC2;
	//components new TimerMilliC() as Timer;

	components ActiveMessageC;
	components new AMSenderC(MESSAGE_TYPE);//numero libero tra 0 e 255
	components new AMReceiverC(MESSAGE_TYPE);

	components new Msp430Uart0C();
	components PrintfC, SerialStartC;

	

	MacchinaC.Boot -> MainC;
	MacchinaC.Leds -> LedsC;
	//MacchinaC.Timer -> Timer;
	MacchinaC.TimerRCV -> TimerC1;
	MacchinaC.TimerRadio -> TimerC2;

	MacchinaC.Radio -> ActiveMessageC;
	MacchinaC.Packet -> AMSenderC;
	MacchinaC.AMSend -> AMSenderC;
	
	MacchinaC.Receive -> AMReceiverC;

	MacchinaC.Resource -> Msp430Uart0C;
	MacchinaC.UartStream-> Msp430Uart0C;
	MacchinaC.Msp430UartConfigure <- Msp430Uart0C;
    
    }

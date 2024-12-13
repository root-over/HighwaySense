configuration TelosbAppC{

}

implementation {
	components LedsC, MainC, TelosbC;
	components new TimerMilliC() as TimerReceivedC;
	components new TimerMilliC() as TimerRadioC;
	
	components ActiveMessageC;
	components new AMSenderC(MESSAGE_TYPE);//numero libero tra 0 e 255
	components new AMReceiverC(MESSAGE_TYPE);
	
	components new Msp430Uart0C();
	components PrintfC, SerialStartC;
	
	TelosbC.Boot -> MainC.Boot;
	TelosbC.Leds -> LedsC;
	TelosbC.TimerReceived -> TimerReceivedC;
	TelosbC.TimerRadio -> TimerRadioC;
	
	TelosbC.Radio -> ActiveMessageC;
	TelosbC.Packet -> AMSenderC;
	TelosbC.AMSend -> AMSenderC;
	TelosbC.Receive -> AMReceiverC;
	
	TelosbC.Resource -> Msp430Uart0C;
	TelosbC.UartStream -> Msp430Uart0C;
	TelosbC.Msp430UartConfigure <- Msp430Uart0C;
}

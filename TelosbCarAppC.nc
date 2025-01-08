configuration TelosbCarAppC{
}

implementation {
	components MainC, TelosbCarC;
	components new TimerMilliC() as TimerReceivedC;
	components new TimerMilliC() as TimerRadioC;
	
	components ActiveMessageC;
	components new AMSenderC(MESSAGE_TYPE);
	components new AMReceiverC(MESSAGE_TYPE);
	
	components new Msp430Uart0C();
	components PrintfC, SerialStartC;
	
	TelosbCarC.Boot -> MainC.Boot;
	TelosbCarC.TimerReceived -> TimerReceivedC;
	TelosbCarC.TimerRadio -> TimerRadioC;
	
	TelosbCarC.Radio -> ActiveMessageC;
	TelosbCarC.Packet -> AMSenderC;
	TelosbCarC.AMSend -> AMSenderC;
	TelosbCarC.Receive -> AMReceiverC;
	
	TelosbCarC.Resource -> Msp430Uart0C;
	TelosbCarC.UartStream -> Msp430Uart0C;
	TelosbCarC.Msp430UartConfigure <- Msp430Uart0C;
}

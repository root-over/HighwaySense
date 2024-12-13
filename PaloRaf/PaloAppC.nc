configuration PaloAppC{

}

implementation {
	components MainC, PaloC, LedsC;
	components new TimerMilliC() as TimerBroadcastC;
	components new TimerMilliC() as TimerPaloC;
	
	components ActiveMessageC;
	components new AMSenderC(MESSAGE_TYPE);//numero libero tra 0 e 255
	components new AMReceiverC(MESSAGE_TYPE);
	components PrintfC, SerialStartC;
	
	PaloC.Boot -> MainC.Boot;
	PaloC.Leds -> LedsC;
	PaloC.TimerBroadcast -> TimerBroadcastC;
	PaloC.TimerPalo -> TimerPaloC;
	
	PaloC.Radio -> ActiveMessageC;
	PaloC.Packet -> AMSenderC;
	PaloC.AMSend -> AMSenderC;
	PaloC.Receive -> AMReceiverC;
}

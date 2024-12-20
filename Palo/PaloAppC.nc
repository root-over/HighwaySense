configuration PaloAppC{

}

implementation {
	components MainC, PaloC;
	components new TimerMilliC() as TimerC;
	
	components ActiveMessageC;
	components new AMSenderC(MESSAGE_TYPE);//numero libero tra 0 e 255
	components new AMReceiverC(MESSAGE_TYPE);
        components PrintfC, SerialStartC;
	
	PaloC.Boot -> MainC.Boot;
	PaloC.Timer -> TimerC;
        PaloC.Palo -> TimerC;
	
	PaloC.Radio -> ActiveMessageC;
	PaloC.Packet -> AMSenderC;
	PaloC.AMSend -> AMSenderC;
	
	PaloC.Receive -> AMReceiverC;
}
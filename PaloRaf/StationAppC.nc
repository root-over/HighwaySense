configuration StationAppC{
}

implementation {
	components MainC, StationC;
	components new TimerMilliC() as TimerBroadcastC;
	components new TimerMilliC() as TimerStationC;
	
	components ActiveMessageC;
	components new AMSenderC(MESSAGE_TYPE);
	components new AMReceiverC(MESSAGE_TYPE);
	components PrintfC, SerialStartC;
	
	StationC.Boot -> MainC.Boot;
	StationC.TimerBroadcast -> TimerBroadcastC;
	StationC.TimerStation -> TimerStationC;
	
	StationC.Radio -> ActiveMessageC;
	StationC.Packet -> AMSenderC;
	StationC.AMSend -> AMSenderC;
	StationC.Receive -> AMReceiverC;
}

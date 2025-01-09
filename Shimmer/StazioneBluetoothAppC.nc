configuration StazioneBluetoothAppC {
}

implementation {
  components MainC, StazioneBluetoothC;
  StazioneBluetoothC -> MainC.Boot;
  components new TimerMilliC() as ResetTimer;
  StazioneBluetoothC.ResetTimer -> ResetTimer;
  components new TimerMilliC() as RadioTimer;
  StazioneBluetoothC.RadioTimer -> RadioTimer;

  components LedsC;
  StazioneBluetoothC.Leds -> LedsC;

  components new TimerMilliC() as activityTimer;
  StazioneBluetoothC.activityTimer -> activityTimer;

  components PrintfC, SerialStartC;
  components ActiveMessageC;
  components new AMSenderC(MESSAGE_TYPE);
  components new AMReceiverC(MESSAGE_TYPE);

	StazioneBluetoothC.Radio -> ActiveMessageC;
  StazioneBluetoothC.Packet -> AMSenderC;
  StazioneBluetoothC.AMSend -> AMSenderC;
  StazioneBluetoothC.Receive -> AMReceiverC;
  components RovingNetworksC;
  StazioneBluetoothC.BluetoothInit -> RovingNetworksC.Init;
  StazioneBluetoothC.BTStdControl -> RovingNetworksC.StdControl;
  StazioneBluetoothC.Bluetooth    -> RovingNetworksC;
}
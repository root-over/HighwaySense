configuration TestBluetoothAppC {
}

implementation {
  components MainC, TestBluetoothC;
  TestBluetoothC -> MainC.Boot;

  components new TimerMilliC() as ResetTimer;
  TestBluetoothC.ResetTimer -> ResetTimer;
  components new TimerMilliC() as ResetTimerB;
  TestBluetoothC.ResetTimerB -> ResetTimerB;

  components LedsC;
  TestBluetoothC.Leds -> LedsC;

  components new TimerMilliC() as activityTimer;
  TestBluetoothC.activityTimer -> activityTimer;

  components PrintfC, SerialStartC;

	

  components ActiveMessageC;

  components new AMSenderC(MESSAGE_TYPE);//numero libero tra 0 e 255

  components new AMReceiverC(MESSAGE_TYPE);

	

  TestBluetoothC.Radio -> ActiveMessageC;

  TestBluetoothC.Packet -> AMSenderC;

  TestBluetoothC.AMSend -> AMSenderC;

  TestBluetoothC.Receive -> AMReceiverC;
  
  components RovingNetworksC;
  TestBluetoothC.BluetoothInit -> RovingNetworksC.Init;
  TestBluetoothC.BTStdControl -> RovingNetworksC.StdControl;
  TestBluetoothC.Bluetooth    -> RovingNetworksC;
}
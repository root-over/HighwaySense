#include "msp430usart.h"
#include "printf.h"
#include "Message.h"


#define SOP 60
#define EOP 62

module MacchinaC {
    uses interface Boot;
    uses interface Leds;
    //uses interface Timer<TMilli> as Timer;
    uses interface Timer<TMilli> as TimerRCV;
    uses interface Timer<TMilli> as TimerRadio;

    uses interface SplitControl as Radio;
    uses interface Packet;
    uses interface AMSend;
    uses interface Receive;

    uses interface Read<uint16_t> as Temperature;
    uses interface Resource;
    uses interface UartStream;

    provides {
        interface Msp430UartConfigure;
    }
}

implementation {
    const uint32_t PERIOD=5000;
    uint8_t notificaAuto = 0;
    uint16_t mes = 0;

    message_t pkt;
    MyPayload* myState;
    MyPayload* pktReceived;

    uint8_t DataUart[5]; 
    uint8_t receivedData[32]; 
    uint16_t ArduinoData; 
    uint16_t Celsius = 0;

    msp430_uart_union_config_t msp430_uart_9600_config = {
        {
            utxe : 1,
            urxe : 1,
            ubr : UBR_1MHZ_9600,
            umctl : UMCTL_1MHZ_9600,
            ssel : 0x02,
            pena : 0,
            pev : 0,
            spb : 1,
            clen : 1, listen : 0, mm : 0, ckpl : 0,
            urxse : 0,
            urxeie : 1,
            urxwie : 0,
        }
    };

    async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
        return &msp430_uart_9600_config;
    }

    event void Boot.booted() {
		call Radio.start();//Attivo la radio per ricevere messaggi dal palo
		myState = (MyPayload*)(call Packet.getPayload(&pkt, sizeof(MyPayload)));//Inizializzo messaggio da mandare al palo
		call TimerRCV.startPeriodic(1024);//Richiamo timerRCV per ricevere dati auto
		
	}

   event void Radio.startDone(error_t code){
		if (code == SUCCESS)
			call Leds.led1On();
		else
			call Radio.start();
	}
	
	event void Radio.stopDone(error_t code){
		call Leds.led1Off();
	}
	
	event void AMSend.sendDone(message_t* msg, error_t code){
		if (code == FAIL)
			call Leds.led0On();
		else
			call Leds.led2Off();
	}
    
    event void TimerRCV.fired() {
        call Leds.led1Toggle();

        call Temperature.read();
        call Resource.request();

        printf("Dati Inviati = %d\n", Celsius);

        ArduinoData = receivedData[1] << 8 | receivedData[0]; 
	
	printf("%d\n",ArduinoData);

	if (ArduinoData == 29268){
		Celsius= 1;
		printf("Dati Ricevuti da esp: = %s\n", "Traffico");
	}
	if (ArduinoData == 20307){
		Celsius= 2;
		printf("Dati Ricevuti da esp: = %s\n", "SOS");
	}
	if (ArduinoData == 28233){
		Celsius= 3;
		printf("Dati Ricevuti da esp: = %s\n", "Incidente");
	}
	if (ArduinoData == 19279){
		Celsius= 3;
		printf("Dati Ricevuti da esp: = %s\n", "OK");
	}
	if (ArduinoData == 24908){
		Celsius= 3;
		printf("Dati Ricevuti da esp: = %s\n", "Lavori in corso");
	}
        printfflush();
    }

    event void Temperature.readDone(error_t code, uint16_t data) {
        if (code == SUCCESS) {
            //Celsius = (-39 + 0.01 * data);
		//Celsius =1;
            DataUart[2] = Celsius >> 8;
            DataUart[1] = Celsius & 0xff;
        }
    }

    //Ho ricevuto il messaggio broadcast dal palo
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
		if (payloadLength == sizeof(MyPayload)){//pacchetto ricevuto dal palo
			call Leds.led1On();
			pktReceived = (MyPayload*)payload;
			
			if (pktReceived->traffico)//Studio il messaggio arrivato
				notificaAuto = 1;
			else if (pktReceived->incidente)
				notificaAuto = 2;
			else if (pktReceived->lavori_in_corso)
				notificaAuto = 3;
			else if (pktReceived->sos)
				notificaAuto = 4;
			//inviare notificaAuto
			
			//finisco di compilare il messaggio da dover inoltrare
			myState->myNodeid = TOS_NODE_ID;
			myState->lavori_in_corso = FALSE;
			myState->mes_Aggiuntivo = mes;
			call AMSend.send(pktReceived->myNodeid, &pkt, sizeof(MyPayload));
		}
		call Radio.stop();//Smetto di ascoltare in ricezione i messaggi dei pali
		call TimerRadio.startOneShot(PERIOD);//Attendo PERIOD e riattivo la radio
		return msg;
	}

	event void TimerRadio.fired(){
		call Radio.start();
	}

    event void Resource.granted() {
        DataUart[0] = SOP;
        DataUart[3] = EOP;

        if (call UartStream.send(DataUart, 5) == SUCCESS) {
            call Leds.led0Toggle();
        }
        
        if (call UartStream.receive(receivedData, 2) == SUCCESS) { 
            call Leds.led1Toggle();
        }
    }

    async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t error) { 
        call Resource.release();
    }

    async event void UartStream.receivedByte(uint8_t byte) {
        call Resource.release();
    }
    
    async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t error) { 
        call Resource.release();
    }
}

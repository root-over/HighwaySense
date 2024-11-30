#include "msp430usart.h"
#include "printf.h"
#include "Message.h"


#define SOP 60
#define EOP 62

module MacchinaC {
    uses interface Boot;
    uses interface Leds;
    uses interface Timer<TMilli> as TimerRCV;
    uses interface Timer<TMilli> as TimerRadio;

    uses interface SplitControl as Radio;
    uses interface Packet;
    uses interface AMSend;
    uses interface Receive;

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

    uint16_t myNodeid;
	bool traffico;
	bool incidente;
	bool lavori_in_corso;
    bool sos;
	uint16_t mes_Aggiuntivo;

    message_t pkt;
    MyPayload* myState;
    MyPayload* pktReceived;

    uint8_t DataUart[6]; 
    uint8_t receivedData[32]; 
    uint16_t EspData;

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
        call Resource.request();
    printf("Dati Inviati Uart 1 = %d\n", DataUart[1]);
	printf("Dati Inviati Uart 2 = %d\n", DataUart[2]);
	printf("Dati Inviati Uart 3 = %d\n", DataUart[3]);
	printf("Dati Inviati Uart 4 = %d\n", DataUart[4]);

        EspData = receivedData[1] << 8 | receivedData[0]; 
	
	//Questa print serve solo a vedere il numero trasmesso dall'esp via uart
	//printf("%d\n",EspData);

	if (EspData == 29268){
        //Metto direttamente il valore dentro la variabile
		myState->traffico = TRUE;
		printf("esp: = %s\n", "Traffico");
	}else{
        	myState->traffico = FALSE;
    }
	if (EspData == 20307){
		myState->sos = TRUE;
		printf("esp: = %s\n", "SOS");
	}else{
        myState->sos = FALSE;
    }
	if (EspData == 28233){
		myState->incidente = TRUE;
		printf("esp: = %s\n", "Incidente");
	}else{
        myState->incidente = FALSE;
    }
	if (EspData == 19279){
		printf("esp: = %s\n", "OK");
	}
	if (EspData == 24908){
		printf("esp: = %s\n", "Lavori in corso");
	}
        printfflush();
    }

    //Ho ricevuto il messaggio broadcast dal palo
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
		if (payloadLength == sizeof(MyPayload)){//pacchetto ricevuto dal palo
			call Leds.led1On();
			pktReceived = (MyPayload*)payload;
            
            notificaAuto = 0;
            if (pktReceived->traffico) // Studio il messaggio arrivato
                notificaAuto |= 1 << 0;
            if (pktReceived->incidente)
                notificaAuto |= 1 << 1;
            if (pktReceived->lavori_in_corso)
                notificaAuto |= 1 << 2;
            if (pktReceived->sos)
                notificaAuto |= 1 << 3;
			//inviare notificaAuto

            if (notificaAuto & (1 << 0)) { //Messaggi che vanno mandati all'esp per notificare la macchina
                //Metto 1 nel bit 1 del messaggio da mandare all'esp via uart 
                printf("Traffico\n");
                DataUart[1]=1;
            }else{
                DataUart[1]=0;
            }
            if (notificaAuto & (1 << 1)) {
                printf("Incidente\n");
                DataUart[2]=1;
            }else{
                DataUart[2]=0;
            }
            if (notificaAuto & (1 << 2)) {
                printf("Lavori in corso\n");
                DataUart[3]=1;
            }else{
                DataUart[3]=0;
            }
            if (notificaAuto & (1 << 3)) {
                printf("SOS\n");
                DataUart[4]=1;
            }else{
                DataUart[4]=0;
            }
			//finisco di compilare il messaggio da dover inoltrare
			myState->myNodeid = TOS_NODE_ID;
			myState->lavori_in_corso = FALSE;
			myState->mes_Aggiuntivo = mes;

		    //TODO RIMUOVERE messaggio modificato prima dell'invio per simulazione
		    myState->incidente=TRUE;
            myState->sos=TRUE;

            //La macchina manda al palo solo se il palo gli ha comunicato prima il suo id, serve a capire a quale palo la macchina è connessa
            printf("Pacchetto trasmesso al palo: %p\n", &pkt);
            printf("myNodeid: %d\n", myState->myNodeid);
            printf("traffico: %d\n", myState->traffico);
            printf("incidente: %d\n", myState->incidente);
            printf("lavori_in_corso: %d\n", myState->lavori_in_corso);
            printf("sos: %d\n", myState->sos);
            printf("mes_Aggiuntivo: %d\n", myState->mes_Aggiuntivo);
			call AMSend.send(pktReceived->myNodeid, &pkt, sizeof(MyPayload)); 
		}

        // TODO Per test togliere lo stop in modo da ricevere continuamente messaggi dal palo
		call Radio.stop();//Smetto di ascoltare in ricezione i messaggi dei pali
		call TimerRadio.startOneShot(PERIOD);//Attendo PERIOD e riattivo la radio
		return msg;
	}

	event void TimerRadio.fired(){
		call Radio.start();
	}

    event void Resource.granted() {
        DataUart[0] = SOP;
        DataUart[5] = EOP;

        if (call UartStream.send(DataUart, 6) == SUCCESS) {
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

#include "Message.h"
#include "printf.h"
#include "msp430usart.h"

/*
1)L'auto riceve il messaggio contenente i dati di stato della strada dal palo e li inoltra al conducente;
2)L'auto conosce i propri messaggi di stato, forma il messaggio e lo invia al palo
*/

#define SOP 60
#define EOP 62

#define PERIOD_SLEEP 3000
#define PERIOD_FROM_CAR 1000

module TelosbC{
	uses interface Boot;
	uses interface Leds;
	uses interface Timer<TMilli> as TimerReceived;
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

implementation{
	//message_t pkt_received;
	message_t pkt_to_send;
	MyPayload* pktReceived;
	MyPayload* pktToSend;
	
	//VARIABILI RELATIVE A COMUNICAZIONE UART
	uint8_t DataUart[5];
	uint8_t DataReceived[32];
	uint16_t Arduino;
	
	//CODICE RELATIVO ALLA CONNESSIONE UART
	msp430_uart_union_config_t msp430_uart_9600_config = {
		{
			utxe: 1,
			urxe: 1,
			ubr: UBR_1MHZ_9600,
			umctl: UMCTL_1MHZ_9600,
			ssel: 0x02,
			pena: 0,
			pev: 0,
			spb: 1,
			clen: 1,
			listen: 0,
			mm: 0,
			ckpl: 0,
			urxse: 0,
			urxeie: 1,
			urxwie: 0,
		}
	};
	
	async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig(){
		return &msp430_uart_9600_config;
	}
	
	async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t error){
		call Resource.release();
	}
	
	async event void UartStream.receivedByte(uint8_t byte){
		call Resource.release();
	}
	
	async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t error){
		call Resource.release();
	}
	
	event void Resource.granted(){
		DataUart[0] = SOP;
		DataUart[3] = EOP;
	}
	
	event void TimerReceived.fired(){
		call Resource.request();
		
		Arduino = DataReceived[1] << 8 | DataReceived[0];
		printf("Arduino:%d\n",Arduino);
		if(Arduino == 29268)
			printf("Dati ricevuti da esp: = %s\n","Traffico");
		if(Arduino == 20307)
			printf("Dati ricevuti da esp: = %s\n","SOS");
		if(Arduino == 28233)
			printf("Dati ricevuti da esp: = %s\n","Incidente");
		if(Arduino == 19279)
			printf("Dati ricevuti da esp: = %s\n","OK");
		if(Arduino == 24908)
			printf("Dati ricevuti da esp: = %s\n","Lavori");
		printfflush();
	}
	
	//CODICE RELATIVO ALLA CONNESSIONE RADIO
	event void Boot.booted(){
		call Radio.start();
		printf("Radio accesa\n");
		pktToSend = (MyPayload*)(call Packet.getPayload(&pkt_to_send, sizeof(MyPayload)));
		//IMPOSTO DI DEFAULT ALCUNI TRATTI DEL MESSAGGIO CHE NON VERRANNO STUDIATI DAI PALI
		pktToSend->myNodeid = TOS_NODE_ID;
		pktToSend->traffico = FALSE;
		pktToSend->lavori_in_corso = FALSE;
		pktToSend->broad = FALSE;
		pktToSend->mes_Aggiuntivo = 0;
		call TimerReceived.startPeriodic(PERIOD_FROM_CAR);
		printf("TimerReceived avviato\n");
		printfflush();
	}
	
	event void Radio.startDone(error_t code){
		printf("Radio avviata ");
		if(code == SUCCESS){
			printf("con successo\n");
			call Leds.led1On();
		}else{
			printf("con errore\n");
		}
		printfflush();
	}
	
	event void Radio.stopDone(error_t code){
		printf("Radio spenta ");
		if(code == SUCCESS){
			printf("con successo\n");
			call Leds.led1Off();
		}else{
			printf("con errore\n");
		}
		printfflush();	
	}
	
	event void AMSend.sendDone(message_t* msg, error_t code){
		//printf("Send del messaggio verso palo avvenuta ");
		if(code == SUCCESS){
			//printf("con successo\n");
			call Leds.led2Toggle();
		}else{
			//printf("con errore\n");
		}
		//printfflush();
	}
	
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
		if (payloadLength == sizeof(MyPayload)){
			printf("Pacchetto arrivato con i seguenti dati:\n");
			pktReceived = (MyPayload*)payload;
			
			printf("PoleId: %d\tTr: %d\tInc: %d\tLav: %d\tSos: %d\n",pktReceived->mes_Aggiuntivo, pktReceived->traffico, pktReceived->incidente, pktReceived->lavori_in_corso, pktReceived->sos);
			
			//NOTIFICARE AUTO
			printf("Auto notificata\n");
		
			printf("Sto inviando i seguenti dati:\n");
			//MODIFICARE PKT_TO_SEND CON I DATI DELL'AUTO---I SEGUENTI SONO MESSI DI DEFAULT PER PROVA
			pktToSend->incidente = FALSE;
			pktToSend->sos = FALSE;
			
			printf("MyId: %d\tTr: %d\tInc: %d\tLav: %d\tSos: %d\n",pktToSend->myNodeid, pktToSend->traffico, pktToSend->incidente, pktToSend->lavori_in_corso, pktToSend->sos);
			call AMSend.send(pktReceived->myNodeid, &pkt_to_send, sizeof(MyPayload));
			printf("Pacchetto inviato al palo\n");
			
			call Radio.stop();
			call TimerRadio.startOneShot(PERIOD_SLEEP);
			printfflush();
			return msg;
		}
	}
	
	event void TimerRadio.fired(){
		printf("Sto accendendo la radio... ");
		call Radio.start();
	}
	
}

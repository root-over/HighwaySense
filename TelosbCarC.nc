#include "Message.h"
#include "printf.h"
#include "msp430usart.h"

#define SOP 60
#define EOP 62

#define PERIOD_SLEEP 5000
#define PERIOD_FROM_CAR 1000

module TelosbCarC{
	uses interface Boot;
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

	message_t pkt_to_send;
	MyPayload* pktReceived;
	MyPayload* pktToSend;
	
	// UART
	uint8_t DataUart[5];
	uint8_t DataReceived[32];
	uint16_t Arduino;
	
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
	
	//RADIO
	event void Boot.booted(){
		call Radio.start();
		pktToSend = (MyPayload*)(call Packet.getPayload(&pkt_to_send, sizeof(MyPayload)));
		pktToSend->myNodeid = TOS_NODE_ID;
		pktToSend->traffic = FALSE;
		pktToSend->work_in_progress = FALSE;
		pktToSend->broad = FALSE;
		pktToSend->mes_station_involved = 0;
		call TimerReceived.startPeriodic(PERIOD_FROM_CAR);
	}
	
	event void Radio.startDone(error_t code){
	}
	
	event void Radio.stopDone(error_t code){
	}
	
	event void AMSend.sendDone(message_t* msg, error_t code){
	}
	
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
		if (payloadLength == sizeof(MyPayload)){
			pktReceived = (MyPayload*)payload;
			
			pktToSend->crash = FALSE;
			pktToSend->sos = FALSE;
			
			call AMSend.send(pktReceived->myNodeid, &pkt_to_send, sizeof(MyPayload));
			
			call Radio.stop();
			call TimerRadio.startOneShot(PERIOD_SLEEP);
			return msg;
		}
	}
	
	event void TimerRadio.fired(){
		call Radio.start();
	}
}

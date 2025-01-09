#include "msp430usart.h"
#include "printf.h"
#include "Message.h"

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

implementation {
	message_t pkt_to_send;
	MyPayload* pktReceived;
	MyPayload* pktToSend;

	uint8_t mex_to_car = 0;

	//Uart communication
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

	event void Boot.booted() {
		call Radio.start();
		pktToSend = (MyPayload*)(call Packet.getPayload(&pkt_to_send, sizeof(MyPayload)));
		pktToSend->myNodeid = TOS_NODE_ID;
		pktToSend->traffic = FALSE;
		pktToSend->crash = FALSE;
		pktToSend->sos = FALSE;
		pktToSend->work_in_progress = FALSE;
		pktToSend->broad = FALSE;
		pktToSend->prev_station_problem = FALSE;
		pktToSend->mes_station_involved = 0;
		call TimerReceived.startPeriodic(PERIOD_FROM_CAR);
	}

	event void Radio.startDone(error_t code){
	}
	
	event void Radio.stopDone(error_t code){
	}
	
	event void AMSend.sendDone(message_t* msg, error_t code){
	}
    
	event void TimerReceived.fired() {
        	call Resource.request();

        	EspData = receivedData[1] << 8 | receivedData[0]; 
		if (EspData == 29268){
			pktToSend->traffic = TRUE;
			printf("esp: = %s\n", "Traffic");
		}else{
        		pktToSend->traffic = FALSE;
    		}
		if (EspData == 20307){
			pktToSend->sos = TRUE;
			printf("esp: = %s\n", "SOS");
		}else{
        		pktToSend->sos = FALSE;
   		}
		if (EspData == 28233){
			pktToSend->crash = TRUE;
			printf("esp: = %s\n", "Crash");
		}else{
        		pktToSend->crash = FALSE;
    		}
		if (EspData == 19279){
			printf("esp: = %s\n", "OK");
		}
		if (EspData == 24908){
			printf("esp: = %s\n", "Work in progress");
		}
       		printfflush();
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
		if (payloadLength == sizeof(MyPayload)){
			pktReceived = (MyPayload*)payload;
            
	            	mex_to_car = 0;
	            	if (pktReceived->traffic)
	                	mex_to_car |= 1 << 0;
	            	if (pktReceived->crash)
	                	mex_to_car |= 1 << 1;
	            	if (pktReceived->work_in_progress)
	               		mex_to_car |= 1 << 2;
	            	if (pktReceived->sos)
	                	mex_to_car |= 1 << 3;
	
	            	if (mex_to_car & (1 << 0)) { //Messaggi che vanno mandati all'esp per notificare la macchina
	                //Metto 1 nel bit 1 del messaggio da mandare all'esp via uart 
	                	printf("Traffic\n");
	                	DataUart[1]=1;
	            	}else{
	                	DataUart[1]=0;
	            	}
	            	if (mex_to_car & (1 << 1)) {
			        printf("Crash\n");
			        DataUart[2]=1;
			}else{
	               		DataUart[2]=0;
	            	}
	            	if (mex_to_car & (1 << 2)) {
	                	printf("Work in progress\n");
	               		DataUart[3]=1;
	            	}else{
	                	DataUart[3]=0;
	            	}
	            	if (mex_to_car & (1 << 3)) {
			        printf("SOS\n");
			        DataUart[4]=1;
	            	}else{
	                	DataUart[4]=0;
	            	}
            	
			call AMSend.send(pktReceived->myNodeid, &pkt_to_send, sizeof(MyPayload)); 
		}
		call Radio.stop();
		call TimerRadio.startOneShot(PERIOD_SLEEP);
		return msg;
	}

	event void TimerRadio.fired(){
		call Radio.start();
	}
}

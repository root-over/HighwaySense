#include "Message.h"
#include "Car_message.h"
#include "printf.h"

/*GESTIONE DELL'ATTIVITÀ NEL TEMPO DEL PALO
1)Il palo invia tramite broadcast lo stato della strada
2)Quando riceve un messaggio da auto X studia la struttura dati:
	Se l'auto è già presente allora
	altrimenti inseriscila
3)Un palo invia al successivo le info sul traffio, incidenti ecc.
*/

/*GESTIONE DELLE INFORMAZIONI DI UN SINGOLO PALO
C'è un incidente (incidente==TRUE) quando:
	-L'informazione proviene dalla macchina (in questo caso l'incidente è avvenuto in prossimità del palo stesso);
	-L'informazione proviene dal palo successivo (devo indicare l'id del palo presso cui è avvenuto l'incidente);
C'è un traffico (traffico==TRUE) quando:
	-L'informazione proviene dalla macchina (una stessa auto è registrata più volte presso lo stesso palo); pIU MACCHINE
	-L'informazione proviene dal palo successivo (devo indicare l'id del palo);
C'è un lavori_in_corso (lavori_in_corso==TRUE) quando:
	-L'informazione proviene da manutentori della strada;
	-L'informazione proviene dal palo successivo (devo indicare l'id del palo);
C'è un sos (sos==TRUE) quando:
	-L'informazione proviene dalla macchina (in questo caso l'incidente è avvenuto in prossimità del palo stesso);
*/

#define PERIOD_BROADCAST 500
#define PERIOD_INTERCOMUNICATION 3000
#define MIN_ID_CAR 20
#define MAX_ID_CAR 200
#define NUM_CAR_MIN_TRAFFIC 2


module PaloC{
	uses interface Boot;
	uses interface Leds;
	uses interface Timer<TMilli> as TimerBroadcast;
	uses interface Timer<TMilli> as TimerPalo;
	
	uses interface SplitControl as Radio;
	uses interface Packet;
	uses interface AMSend;
	uses interface Receive;
}

implementation{
	uint8_t j = 0;
	bool evitare;
	
	uint16_t myNodeid, id_corr;
	bool traffico, tr_corr;
	bool incidente, inc_corr;
	bool lavori_in_corso, lav_corr;
	bool sos, sos_corr;
	bool mes_from_broad_corr;
	uint16_t mes_Aggiuntivo, mes_corr;
	
	uint16_t idAutoInc = 0;
	uint16_t bgb;
	
	message_t pkt;
	message_t broad;
	MyPayload* streetState;
	MyPayload* pktReceivedFromCar;
	Auto autoCorrente;
	Auto numAutoPresenti[NUM_MAX_AUTO];
	
	//IMPLEMENTAZIONE TASK
	
	task void controlloTraffico(){
		uint8_t i = 0, a = 0, count_car_traffic = 0;
		uint8_t id_founded_car = 0;
		numAutoPresenti[j] = autoCorrente;
		printf("Ho inserito l'auto %u nel buffer del palo corrente\n", autoCorrente.autoid);
		j++;
		j = j % NUM_MAX_AUTO;
		
		for (i=0; i<NUM_MAX_AUTO && numAutoPresenti[i].autoid > 0; i++){
			for (a=i+1; a<NUM_MAX_AUTO && numAutoPresenti[a].autoid > 0; a++){
				if (numAutoPresenti[i].autoid == numAutoPresenti[a].autoid && id_founded_car != numAutoPresenti[i].autoid){
					printf("Ho trovato auto con id: %u all'interno del buffer del palo\n",numAutoPresenti[i].autoid);
					id_founded_car = numAutoPresenti[i].autoid;
					count_car_traffic++;
					if (count_car_traffic >= NUM_CAR_MIN_TRAFFIC){
						printf("Traffico\n");
						traffico = TRUE;
						mes_Aggiuntivo = TOS_NODE_ID;
						printfflush();
						return;
					}
					break;
				}
			}
		}
		if (traffico && (mes_Aggiuntivo > TOS_NODE_ID))
			return;
			
		traffico = FALSE;
		printf("Non ho trovato traffico\n");
		printfflush();
	}
	
	task void controlloIncidente(){
		uint8_t i = 0;
		for (i=0; i<NUM_MAX_AUTO && numAutoPresenti[i].autoid > 0; i++)
			if(numAutoPresenti[i].autoid == idAutoInc){
				printf("Auto incidentata\n");
				printfflush();
				return;
			}
		printf("Nessuna auto incidentata\n");
		printfflush();
		incidente = FALSE;
		idAutoInc = 0;
		mes_Aggiuntivo = 0;
	}
	
	//IMPLEMENTAZIONE EVENTI
	
	event void Boot.booted(){
		call Radio.start();
		//Inizializzazione di default
		bgb = 0;
		traffico = FALSE;
		incidente = FALSE;
		lavori_in_corso = FALSE;
		sos = FALSE;
		mes_Aggiuntivo = 0;
		printf("\n\n\n\n\n\n\n\n");
		//printf("Traf: %d, Inc: %d, Lav: %d, Sos: %d, Palo: %d\n",traffico,incidente,lavori_in_corso,sos,mes_Aggiuntivo);
		
		//call TimerBroadcast.startPeriodic(PERIOD_BROADCAST);
		//printf("Timer per comunicazione broadcast partito\n");
		call TimerPalo.startPeriodic(PERIOD_INTERCOMUNICATION);
		//printf("Timer per inter-comunicazione partito\n");
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
		//printf("Send del messaggio avvenuta ");
		if(code == SUCCESS){
			//printf("con successo\n");
			//call Leds.led2Toggle();
		}else{
			//printf("con errore\n");
		}
		//printfflush();
	}
	
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
		if (payloadLength == sizeof(MyPayload)){
			evitare = TRUE;
			pktReceivedFromCar = (MyPayload*)payload;
			
			id_corr = pktReceivedFromCar->myNodeid;
			tr_corr = pktReceivedFromCar->traffico;
			inc_corr = pktReceivedFromCar->incidente;
			lav_corr = pktReceivedFromCar->lavori_in_corso;
			sos_corr = pktReceivedFromCar->sos;
			mes_from_broad_corr = pktReceivedFromCar->broad;
			mes_corr = pktReceivedFromCar->mes_Aggiuntivo;
			
			printf("%u %u %u %u %u %u", id_corr, tr_corr, inc_corr, lav_corr, sos_corr, mes_corr);
			
			//Se ho ricevuto il pacchetto dal palo successivo:
			if((id_corr == TOS_NODE_ID + 1) && !mes_from_broad_corr){
				printf("Pacchetto arrivato dal palo\n");
				printf("Mex agg:%d\n",mes_Aggiuntivo);
				call Leds.led0Toggle();
				evitare = FALSE;
				if ((tr_corr) && (mes_Aggiuntivo != TOS_NODE_ID)){
					traffico = TRUE;
					printf("%s al palo: %d\n","Traffico",mes_corr);
				}
				if ((pktReceivedFromCar->incidente) && (mes_Aggiuntivo != TOS_NODE_ID)){
					incidente = TRUE;
					printf("%s al palo: %d\n","Incidente",mes_corr);
				}
				if ((pktReceivedFromCar->lavori_in_corso) && (mes_Aggiuntivo != TOS_NODE_ID)){
					lavori_in_corso = TRUE;
					printf("%s al palo: %d\n","Lavori",mes_corr);
				}
				if ((pktReceivedFromCar->sos) && (mes_Aggiuntivo != TOS_NODE_ID)){
					sos = TRUE;
					printf("%s al palo: %d\n","Sos",mes_corr);
				}
				if(tr_corr || inc_corr || lav_corr || sos_corr){
					printf("Verifica\n");
					if(mes_Aggiuntivo != TOS_NODE_ID)
						mes_Aggiuntivo = mes_corr;
				}else
					if(mes_Aggiuntivo > TOS_NODE_ID)
						mes_Aggiuntivo = 0;
				printf("new mex agg: %u\n", mes_Aggiuntivo);
				printfflush();
			}
			
			//Se ho ricevuto il pacchetto da un'auto:
			if((pktReceivedFromCar->myNodeid > MIN_ID_CAR) && (pktReceivedFromCar->myNodeid < MAX_ID_CAR)){
				printf("Pacchetto arrivato da un'auto\n");
				evitare = FALSE;
	
				/*autoCorrente->autoid = pktReceivedFromCar->myNodeid;
				printf("IdAuto: %u - ", autoCorrente->autoid);
				//%u per gli interi senza segno
				autoCorrente->incidente = pktReceivedFromCar->incidente;
				printf("Inc: %d - ", autoCorrente->incidente);
				//autoCorrente->traffico = pktReceivedFromCar->traffico;
				//printf("Tra: %d - ", autoCorrente->traffico);
				autoCorrente->sos = pktReceivedFromCar->sos;
				printf("Sos: %d \n", autoCorrente->sos);
				//autoCorrente->lavori_in_corso = pktReceivedFromCar->lavori_in_corso;
				//printf("Lavori: %d\n", autoCorrente->lavori_in_corso);
				printfflush();
				*/
				
				autoCorrente.autoid=id_corr;
				autoCorrente.incidente=inc_corr;
				autoCorrente.sos=sos_corr;
				printf("Id: %u\tInc: %u\tSos: %u\n", id_corr, inc_corr, sos_corr);
				
				printf("Il segnale di sos corrente e': %d\n",sos_corr);
				if(sos_corr)
					printf("Auto %d ha inviato un sos pari a: %d\n",id_corr, sos_corr);
					//NOTIFICO L'APP
				
				post controlloTraffico();
				
				printf("Mentre quello di incidente e': %d\n",inc_corr);
				if (inc_corr){
					printf("Auto %d ha avuto un incidente\n",id_corr);
					incidente = TRUE;
					idAutoInc = id_corr;
					mes_Aggiuntivo = TOS_NODE_ID;
				}
				
				if (idAutoInc == autoCorrente.autoid)
					post controlloIncidente();
				
				printfflush();
			}
			printfflush();
			//Se è un messaggio da evitare termina la Receive
			
			if(evitare)
				return msg;
		}
		return msg;
	}

	event void TimerBroadcast.fired(){
		streetState = (MyPayload*)(call Packet.getPayload( &broad, sizeof(MyPayload)));
		streetState->myNodeid = TOS_NODE_ID;
		streetState->traffico = traffico;
		streetState->incidente = incidente;
		streetState->lavori_in_corso = lavori_in_corso;
		streetState->sos = sos;
		streetState->broad = TRUE;
		streetState->mes_Aggiuntivo = mes_Aggiuntivo;
		printf("MyNode: %d, Traf: %d, Inc: %d, Lav: %d, Sos: %d, Palo: %d",TOS_NODE_ID,traffico,incidente,lavori_in_corso,sos,mes_Aggiuntivo);
		printf("-Messaggio broadcast\n");
		printfflush();
		call AMSend.send(ID_BROADCAST, &broad, sizeof(MyPayload));
	}
	
	event void TimerPalo.fired(){
		if(bgb%5==0)
			incidente=!incidente;
		streetState = (MyPayload*)(call Packet.getPayload( &pkt, sizeof(MyPayload)));
		streetState->myNodeid = TOS_NODE_ID;
		streetState->traffico = traffico;
		streetState->incidente = incidente;
		streetState->lavori_in_corso = lavori_in_corso;
		streetState->sos = sos;
		streetState->broad = FALSE;
		if(incidente)
			mes_Aggiuntivo = TOS_NODE_ID;
		streetState->mes_Aggiuntivo = mes_Aggiuntivo;
		printf("MyNode: %d, Traf: %d, Inc: %d, Lav: %d, Sos: %d, Palo: %d",TOS_NODE_ID,traffico,incidente,lavori_in_corso,sos,mes_Aggiuntivo);
		printf("-Messaggio palo\n");
		printfflush();
		call AMSend.send(TOS_NODE_ID - 1, &pkt, sizeof(MyPayload));
		mes_Aggiuntivo = 0;
		bgb++;
	}
}

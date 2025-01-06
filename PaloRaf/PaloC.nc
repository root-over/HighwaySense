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
	
	uint16_t myNodeid, id_corr;
	bool traffico, tr_car, tr_pole;
	bool incidente, inc_car, inc_pole;
	bool lavori_in_corso, lav_car, lav_pole;
	bool sos, sos_car, sos_pole;
	bool mes_from_broad;
	uint16_t mes_Aggiuntivo, mes_pole;
	
	uint16_t idAutoInc = 0;
	
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
						tr_car = TRUE;
						printfflush();
						return;
					}
					break;
				}
			}
		}
			
		traffico = FALSE;
		printf("Non ho trovato traffico\n");
		printfflush();
		return;
	}
	
	task void controlloIncidente(){
		uint8_t i;
		for (i=0; i<NUM_MAX_AUTO && numAutoPresenti[i].autoid > 0; i++)
			if(numAutoPresenti[i].autoid == idAutoInc){
				printf("Auto incidentata\n");
				inc_car = TRUE;
				return;
			}
		printf("Nessuna auto incidentata\n");
		inc_car = FALSE;
		idAutoInc = 0;
		return;
	}
	
	//IMPLEMENTAZIONE EVENTI
	
	event void Boot.booted(){
		call Radio.start();
		//Inizializzazione di default
		traffico = FALSE;
		incidente = FALSE;
		lavori_in_corso = FALSE;
		sos = FALSE;
		mes_Aggiuntivo = 0;
		
		call TimerBroadcast.startPeriodic(PERIOD_BROADCAST);
		call TimerPalo.startPeriodic(PERIOD_INTERCOMUNICATION);
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
			pktReceivedFromCar = (MyPayload*)payload;
			
			//Se ho ricevuto il pacchetto dal palo successivo:
			if((pktReceivedFromCar->myNodeid == TOS_NODE_ID + 1) && !mes_from_broad){
				//Mi memorizzo i messaggi in arrivo dal palo e non faccio nessun controllo
				tr_pole = pktReceivedFromCar->traffico;
				inc_pole = pktReceivedFromCar->incidente;
				lav_pole = pktReceivedFromCar->lavori_in_corso;
				sos_pole = pktReceivedFromCar->sos;
				mes_pole = pktReceivedFromCar->mes_Aggiuntivo;
			
			
				printf("Pacchetto arrivato dal palo\n");
				call Leds.led0Toggle();
				
				printfflush();
			}
			
			//Se ho ricevuto il pacchetto da un'auto:
			if((pktReceivedFromCar->myNodeid > MIN_ID_CAR) && (pktReceivedFromCar->myNodeid < MAX_ID_CAR)){
				printf("Pacchetto arrivato da un'auto\n");
				call Leds.led2Toggle();
				
				//Memororizzo i dati delle auto e non faccio nessun controllo
				
				autoCorrente.autoid = pktReceivedFromCar->myNodeid;
				autoCorrente.incidente = pktReceivedFromCar->incidente;
				autoCorrente.sos = pktReceivedFromCar->sos;
				sos_car = autoCorrente.sos;
				
				if(pktReceivedFromCar->myNodeid == ID_FOR_CHANGE_WORK)
					lav_car = pktReceivedFromCar->lavori_in_corso;
				//Mi serve a settare i lavori
				
				printfflush();
			}
			
			//Dopo aver aggiornato le variabili in funzione del messaggio arrivato setto i messaggi da dover inviare successivamente
			//Di default metto i messaggi in arrivo dal palo ma se è successo qualcosa relativa al mio stato moddifico tale messaggio
			traffico = tr_pole;
			incidente = inc_pole;
			lavori_in_corso = lav_pole;
			sos = sos_pole;
			mes_Aggiuntivo = mes_pole;
			
			//Passo inizialmente col controllare traffico e incidente
			
			post controlloTraffico();
			//Se ha avuto efficacia avrò tr_car = TRUE
			
			if(autoCorrente.incidente)
				idAutoInc = autoCorrente.autoid;
			post controlloIncidente();
			//Se ha avuto successo avrò inc_car = TRUE
			
			if(!(sos_pole)){
				if (tr_car || inc_car || sos_car || lav_car){
					traffico = tr_car;
					incidente = inc_car;
					lavori_in_corso = lav_car;
					sos = sos_car;
					mes_Aggiuntivo = TOS_NODE_ID;
				}
				else
					mes_Aggiuntivo = 0;
			}
				
			
			printfflush();
			//Se è un messaggio da evitare termina la Receive
			
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
		streetState = (MyPayload*)(call Packet.getPayload( &pkt, sizeof(MyPayload)));
		streetState->myNodeid = TOS_NODE_ID;
		streetState->traffico = traffico;
		streetState->incidente = incidente;
		streetState->lavori_in_corso = lavori_in_corso;
		streetState->sos = sos;
		streetState->broad = FALSE;
		streetState->mes_Aggiuntivo = mes_Aggiuntivo;
		printf("MyNode: %d, Traf: %d, Inc: %d, Lav: %d, Sos: %d, Palo: %d",TOS_NODE_ID,traffico,incidente,lavori_in_corso,sos,mes_Aggiuntivo);
		printf("-Messaggio palo\n");
		printfflush();
		call AMSend.send(TOS_NODE_ID - 1, &pkt, sizeof(MyPayload));
	}
}

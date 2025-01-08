#include "Message.h"
#include "Car_message.h"
#include "printf.h"

#define PERIOD_BROADCAST 500
#define PERIOD_INTERCOMUNICATION 3000
#define MIN_ID_CAR 20
#define MAX_ID_CAR 200
#define NUM_CAR_MIN_TRAFFIC 2

module StazioneC{
	uses interface Boot;
	uses interface Leds;
	uses interface Timer<TMilli> as TimerBroadcast;
	uses interface Timer<TMilli> as TimerStazione;
	
	uses interface SplitControl as Radio;
	uses interface Packet;
	uses interface AMSend;
	uses interface Receive;
}

implementation{
	uint8_t j = 0;
	
	uint16_t my_node_id, id_corr;
	bool traffic, tr_car, tr_station;
	bool crash, crash_car, crash_station;
	bool work_in_progress, wip_car, wip_station;
	bool sos, sos_car, sos_station;
	bool mes_from_broad;
	uint16_t mes_station_involved, mes_station;
	
	uint16_t crashed_car = 0;
	
	message_t pkt;
	message_t broad;
	MyPayload* streetState;
	MyPayload* pktReceivedFromCar;
	Auto current_car;
	Auto buffer_cars[NUM_MAX_CAR];

	//TASKS
	task void trafficControl(){
		uint8_t i = 0, a = 0, count_car_traffic = 0;
		uint8_t id_founded_car = 0;
		
		for (i=0; i<NUM_MAX_CAR && buffer_cars[i].autoid > 0; i++){
			for (a=i+1; a<NUM_MAX_CAR && buffer_cars[a].autoid > 0; a++){
				if (buffer_cars[i].autoid == buffer_cars[a].autoid && id_founded_car != buffer_cars[i].autoid){
					id_founded_car = buffer_cars[i].autoid;
					count_car_traffic++;
					if (count_car_traffic >= NUM_CAR_MIN_TRAFFIC){
						tr_car = TRUE;
						return;
					}
					break;
				}
			}
		}
		tr_car = FALSE;
		return;
	}
	
	task void incidentControl(){
		uint8_t i;
		for (i=0; i<NUM_MAX_AUTO && buffer_cars[i].autoid > 0; i++)
			if(buffer_cars[i].autoid == idAutoInc){
				printf("Auto incidentata\n");
				inc_car = TRUE;
				return;
			}
		printf("Nessuna auto incidentata\n");
		inc_car = FALSE;
		idAutoInc = 0;
		return;
	}
	
	//EVENTS
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

				buffer_cars[j] = current_car;
				j++;
				j = j % NUM_MAX_AUTO;
		
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

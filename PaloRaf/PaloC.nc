#include "Message.h"
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


module PaloC{
	uses interface Boot;
	uses interface Timer<TMilli> as TimerBroadcast;
	uses interface Timer<TMilli> as TimerComunicazionePalo;
	uses interface SplitControl as Radio;
	uses interface Packet;
	uses interface AMSend;
	
	uses interface Receive;
}

implementation{
	const uint32_t PERIOD=200;
	const uint32_t PERIODOPALO=1000;
	uint8_t j = 0;
	
	uint16_t myNodeid;
	bool traffico;
	bool incidente;
	bool lavori_in_corso;
	uint16_t mes_Aggiuntivo;//Ci serve per capire da dove arriva l'informazione--conterrà un id palo
	
	message_t pkt, broad;
	MyPayload* streetState;
	MyPayload* pktReceived;
	Auto* autoCorrente;
	Auto numAutoPresenti[NUM_MAX_AUTO];
 
 /* 
   const char targhe[NUM_MAX_AUTO][8] = {
   "AB123CD", "EF456GH", "IJ789KL", "MN012OP", 
   "QR345ST", "UV678WX", "YZ901AB", "CD234EF",
   "GH567IJ", "KL890MN"
   };
*/
//SEZIONE DELLE IMPLEMENTAZIONI DEI TASK UTILIZZATI NEL CODICE

	task void controlloTraffico(){
		uint8_t i = 0, a = 0;
		//Aggiungo l'auto alla prima posizione utile
		numAutoPresenti[j] = *autoCorrente;
		j++;
		j = j%NUM_MAX_AUTO;
		
		//Controllo la presenza di almeno un'auto salvata due volte
		for (i=0; i<NUM_MAX_AUTO && numAutoPresenti[i].autoid > 0; i++){
			for (a=i+1; a<NUM_MAX_AUTO && numAutoPresenti[a].autoid > 0; a++){
				if (numAutoPresenti[a].autoid == numAutoPresenti[i].autoid){
					traffico = TRUE;
					mes_Aggiuntivo = TOS_NODE_ID;
					return;
				}
			}
		}
		
		//Controllo la presenza di traffico nei pali successivi
		if (traffico && mes_Aggiuntivo > TOS_NODE_ID)
			return;
		
		traffico = FALSE;		
	}
	
//SEZIONE DELLE IMPLEMENTAZIONI DEGLI EVENTI DELLE VARIE INTERFACCE

	event void Boot.booted(){
		call Radio.start();
		//Inizializzazione di default
		traffico = FALSE;
		incidente = FALSE;
		lavori_in_corso = FALSE;
		mes_Aggiuntivo = 0;
		
		call TimerBroadcast.startPeriodic(PERIOD);
		call TimerComunicazionePalo.startPeriodic(PERIODOPALO);
  

	}
		
	event void Radio.startDone(error_t code){
		if (code == FAIL)
			call Radio.start();
	}
	
	event void Radio.stopDone(error_t code){
	}
	
	event void AMSend.sendDone(message_t* msg, error_t code){
		if (code == FAIL)
			call AMSend.send(ID_BROADCAST, &pkt, sizeof(MyPayload));
	}
      
/*
	void printTarga(uint16_t autoid) {
             uint8_t index = autoid % NUM_MAX_AUTO;
             printf("Targa dell'auto %d: %s\n", autoid, targhe[index]);
             printfflush();
        }
*/

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
		if (payloadLength == sizeof(MyPayload)){//Pacchetto ricevuto: verificare se dall'auto o dal palo successivo
			pktReceived = (MyPayload*)payload;
			
			if (pktReceived->myNodeid == TOS_NODE_ID + 1){ //Il messaggio ricevuto è stato inviato dal palo successivo
				if (pktReceived->traffico){
					traffico = TRUE;
					mes_Aggiuntivo = pktReceived->myNodeid;
				}
				if (pktReceived->incidente){
					incidente = TRUE;
					mes_Aggiuntivo = pktReceived->myNodeid;
				}
				if (pktReceived->lavori_in_corso){
					lavori_in_corso = TRUE;
					mes_Aggiuntivo = pktReceived->myNodeid;
				}
			}
			else{
				autoCorrente->autoid = pktReceived->myNodeid;
				autoCorrente->incidente = pktReceived->incidente;
				autoCorrente->sos = pktReceived->sos;
				
				if (autoCorrente->sos)
					//Intervento in caso un auto chieda sos
				
				if (autoCorrente->incidente){//Verifico che l'auto non abbia avvertito un incidente
					incidente = TRUE;
					mes_Aggiuntivo = TOS_NODE_ID;
				}
				
				post controlloTraffico();
			}
			
            //printTarga(autoCorrente->autoid);//stampa la targa			
		}
		return msg;
	}
	
	event void TimerBroadcast.fired(){//Invio Periodicamente lo stato della strada alle auto in broadcast
		streetState = (MyPayload*)(call Packet.getPayload( &broad, sizeof(MyPayload)));
		streetState->myNodeid = TOS_NODE_ID;
		streetState->traffico = traffico;
		streetState->incidente = incidente;
		streetState->sos = FALSE;
		streetState->lavori_in_corso = lavori_in_corso;
		streetState->mes_Aggiuntivo = mes_Aggiuntivo;
		call AMSend.send(ID_BROADCAST, &broad, sizeof(MyPayload));
	}

	event void TimerComunicazionePalo.fired(){//Invio al palo successivo le info
		streetState = (MyPayload*)(call Packet.getPayload( &pkt, sizeof(MyPayload)));
		streetState->myNodeid = TOS_NODE_ID;
		streetState->traffico = traffico;
		streetState->incidente = incidente;
		streetState->sos = FALSE;
		streetState->lavori_in_corso = lavori_in_corso;
		streetState->mes_Aggiuntivo = mes_Aggiuntivo;
		call AMSend.send(TOS_NODE_ID - 1, &pkt, sizeof(MyPayload));
	}
}

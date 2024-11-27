#include "Message.h"

#include "printf.h"



/*

1)Il palo invia tramite broadcast lo stato della strada

2)Quando riceve un messaggio da auto X studia la struttura dati:

	Se l'auto è già presente allora

	altrimenti inseriscila

*/
//3)il palo invia al successivo le info sul traffio , incidenti ecc.



module PaloC{

	uses interface Boot;

	uses interface Timer<TMilli>;

	uses interface Timer<TMilli> as Palo ;

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

	uint16_t mes_Aggiuntivo;

	

	message_t pkt, ms;

	MyPayload* streetState;

	MyPayload* pktReceived;

	Auto* autoCorrente;

	Auto* numAutoPresenti[NUM_MAX_AUTO];

  

   const char targhe[NUM_MAX_AUTO][8] = {

   "AB123CD", "EF456GH", "IJ789KL", "MN012OP", 

   "QR345ST", "UV678WX", "YZ901AB", "CD234EF",

   "GH567IJ", "KL890MN"

   };

	

	event void Boot.booted(){

		call Radio.start();

		//Inizializzazione di default

		traffico = FALSE;

		incidente = FALSE;

		lavori_in_corso = FALSE;

		mes_Aggiuntivo = 0;

		

		call Timer.startPeriodic(PERIOD);

		call Palo.startPeriodic(PERIODOPALO);

  



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





        

	task void controlloTraffico(){

		uint8_t i = 0;

		//Controllo se lauto corrente e già stata salvata, in questo caso e resente il traffico

		while (i<NUM_MAX_AUTO || numAutoPresenti[i] != NULL){

			if ( numAutoPresenti[i]->autoid == autoCorrente->autoid)

				traffico = TRUE;

			i++;

		}

		//Quindi aggiorno numAutoPresenti

		if (i<NUM_MAX_AUTO)

			numAutoPresenti[i] = autoCorrente;

		else {

			numAutoPresenti[j] = autoCorrente;

			i = j+1;

			j = i%NUM_MAX_AUTO;

		}

		

	}

      

        

        void printTarga(uint16_t autoid) {

             uint8_t index = autoid % NUM_MAX_AUTO;

             printf("Targa dell'auto %d: %s\n", autoid, targhe[index]);

             printfflush();

        }





	

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
//numerazione per  i pali

		if (payloadLength == sizeof(MyPayload)){//pacchetto ricevuto dall'auto

			pktReceived = (MyPayload*)payload;

			

			autoCorrente->autoid = pktReceived->myNodeid;
                        if( autoid < TOS_NODE_ID)
                                  //scarta

			autoCorrente->traffico = pktReceived->traffico;

			autoCorrente->incidente = pktReceived->incidente;

			autoCorrente->lavori_in_corso = pktReceived->lavori_in_corso;

			

			if (autoCorrente->incidente)//Verifico che lauto non abbia avvertito un incidente

				incidente = TRUE;



               printTarga(autoCorrente->autoid);//stampa la targa

			

			post controlloTraffico();

			

		}

		return msg;

	}

	





	event void Timer.fired(){//Invio eriodicamente lo stato della strada alle auto in broadcast

		streetState = (MyPayload*)(call Packet.getPayload( &pkt, sizeof(MyPayload)));

		streetState->myNodeid = TOS_NODE_ID;

		streetState->traffico = traffico;

		streetState->incidente = incidente;

		streetState->lavori_in_corso = lavori_in_corso;

		streetState->mes_Aggiuntivo = mes_Aggiuntivo;

		call AMSend.send(ID_BROADCAST, &pkt, sizeof(MyPayload));

	}



	event void Palo.fired(){//Invio al palo precedente le info

		streetState = (MyPayload*)(call Packet.getPayload( &pkt, sizeof(MyPayload)));

		streetState->myNodeid = TOS_NODE_ID;

		streetState->traffico = traffico;

		streetState->incidente = incidente;

		streetState->lavori_in_corso = lavori_in_corso;

		streetState->mes_Aggiuntivo = mes_Aggiuntivo;
                if (TOS_NODE_ID > 1)

		call AMSend.send((TOS_NODE_ID % PALI) - 1, &pkt, sizeof(MyPayload));

	}

}
#include <UserButton.h>
#include "Message.h"
#include "Car_message.h"
#include "printf.h"


#define PERIOD_BROADCAST 500
#define PERIOD_INTERCOMUNICATION 3000
#define MIN_ID_CAR 20
#define MAX_ID_CAR 200
#define NUM_CAR_MIN_TRAFFIC 2

module TestBluetoothC {
  uses {
    interface Boot;
    interface Leds;
    interface Init as BluetoothInit;
    interface StdControl as BTStdControl;
    interface Bluetooth;
    interface Timer<TMilli> as activityTimer;
    interface Timer<TMilli> as ResetTimer;
    interface Timer<TMilli> as ResetTimerB;
    interface SplitControl as Radio;
    interface Packet;
    interface AMSend;
    interface Receive;
  }
}


implementation {
  uint8_t j = 0;
	
  uint16_t myNodeid, id_corr;
  bool traffico, tr_car, tr_pole;
  bool incidente, inc_car, inc_pole;
  bool lavori_in_corso, lav_car, lav_pole;
  bool sos, sos_car, sos_pole;
  bool mes_from_broad;
  uint16_t mes_Aggiuntivo, mes_pole;
	
  uint16_t idAutoInc = 0;
  int static counttra=0;
  int static countlav=0;
  int static countinc=0;	
  message_t pkt;
  message_t broad;
  MyPayload* streetState;
  MyPayload* pktReceivedFromCar;
  Auto autoCorrente;
  Auto numAutoPresenti[NUM_MAX_AUTO];
  bool connected = FALSE; // Stato della connessione
  char buffer[20];
  event void Boot.booted() { 
    // Configurazione del modulo Bluetooth
    call BluetoothInit.init();
    call Bluetooth.setRadioMode(SLAVE_MODE); // Modalità slave
    call Bluetooth.setName("Shimmerfra");   // Nome del dispositivo
    // Concatenazione dei messaggi nel buffer
    call BTStdControl.start();
    strcpy(buffer, "HighwaySense\r\n");
    connected = TRUE;
    call activityTimer.startPeriodic(1000); // 1000 ms = 1 secondo
    call ResetTimer.startOneShot(25000);
    call ResetTimerB.startOneShot(30000);

    
}

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
                char localbuffer[30]; 
		uint8_t i;
		for (i=0; i<NUM_MAX_AUTO && numAutoPresenti[i].autoid > 0; i++)
			if(numAutoPresenti[i].autoid == idAutoInc){
				printf("Auto incidentata\n");
				inc_car = TRUE;
				printfflush();
				return;
			}
		printf("Nessuna auto incidentata\n");
		printfflush();
		inc_car = FALSE;
		idAutoInc = 0;
		return;
	}

 task void sendStuff() {
    char localbuffer[100]; 
    int len;             

 if ((lavori_in_corso == 1 && countlav < 3) ||
        (incidente == 1 && countinc < 3) ||
        (traffico == 1 && counttra < 3)) {
        
        sprintf(localbuffer, " Attenzione ");
        
        if (lavori_in_corso == 1 && countlav < 3) {
            strcat(localbuffer, " ci sono lavori in corso\r\n");
            countlav += 1;
        }
        if (incidente == 1 && countinc < 3) {
            strcat(localbuffer, " c'è un incidente\r\n");
            countinc += 1;
        }
        if (traffico == 1 && counttra < 3) {
            strcat(localbuffer, " possibile traffico ");
            counttra += 1;
        }

        strcat(localbuffer, "piu avanti, fare attenzione!\r\n");

        // Scrittura del messaggio via Bluetooth
        call Bluetooth.write((const uint8_t *)localbuffer, strlen(localbuffer));
    }
 
    len = sprintf(localbuffer, 
                  "MyNode: %d, Traf: %d, Inc: %d, Lav: %d, Sos: %d, Palo: %d\r\n", 
                  TOS_NODE_ID, traffico, incidente, lavori_in_corso, sos, mes_Aggiuntivo);

    if (len > 0 && len < sizeof(localbuffer)) { // Controlla che sprintf non abbia superato il buffer
        if (connected) {
            if (call Bluetooth.write((const uint8_t *)localbuffer, strlen(localbuffer)) == SUCCESS) {
                call Leds.led1Toggle(); // Indica che il messaggio è stato inviato
            } else {
                call Leds.led0On();
            }
        }
    } else {
        call Leds.led2On();
    }
  

}

event void ResetTimer.fired() {
    // Resetta i contatori
    counttra = 0;
    countlav = 0;
    countinc = 0;

    // Riavvia il timer per altri 15 secondi
    call ResetTimer.startOneShot(15000); 
}

event void ResetTimerB.fired() {
    call BTStdControl.stop(); // Spegne il Bluetooth
    call Radio.start();
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
    
    // Riavvia il timer per altri 30 secondi
    call ResetTimerB.startOneShot(30000); 
    
}



event void activityTimer.fired() {
    call Radio.stop();
    call BTStdControl.start();
    post sendStuff();  // Invia i messaggi Bluetooth
}



  async event void Bluetooth.connectionMade(uint8_t status) { 
    call Leds.led0On();  
    call Leds.led2Off();  
  }


  async event void Bluetooth.connectionClosed(uint8_t reason) {
    connected = FALSE; // Stato della connessione aggiornato
    call Leds.led0Off();  // LED spento per indicare disconnessione
    call Leds.led2On();   // LED acceso per indicare disconnessione
    call activityTimer.stop(); 
    call Bluetooth.write((const uint8_t *)"Disconnected!\r", 14);
  }

  async event void Bluetooth.dataAvailable(uint8_t data) {
    call Leds.led1Toggle();
  }

  event void Bluetooth.writeDone() {
    call Leds.led1Toggle(); // Indica successo
  }

  async event void Bluetooth.commandModeEnded() { 
    call Leds.led0On();
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
                        call BluetoothInit.init();
                        call Bluetooth.setRadioMode(SLAVE_MODE); 
                        call Bluetooth.setName("Shimmerfra"); 
                        call BTStdControl.start();
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
				
				if(pktReceivedFromCar->myNodeid == 199)
					lav_car = pktReceivedFromCar->lavori_in_corso;
				//Mi serve a settare i lavori
				
				printfflush();
			}
			
			traffico = tr_pole;
			incidente = inc_pole;
			lavori_in_corso = lav_pole;
			sos = sos_pole;
			mes_Aggiuntivo = mes_pole;
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


}






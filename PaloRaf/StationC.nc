#include "Message.h"
#include "Car_message.h"
#include "printf.h"

#define PERIOD_BROADCAST 500
#define PERIOD_INTERCOMUNICATION 5000
#define MIN_ID_CAR 20
#define MAX_ID_CAR 200
#define NUM_CAR_MIN_TRAFFIC 2
#define ID_FOR_CHANGE_WORK 199
#define NUM_MAX_FOR_STATION_PROBLEM 200

module StationC{
	uses interface Boot;
	uses interface Timer<TMilli> as TimerBroadcast;
	uses interface Timer<TMilli> as TimerStation;
	
	uses interface SplitControl as Radio;
	uses interface Packet;
	uses interface AMSend;
	uses interface Receive;
}

implementation{
	uint8_t j = 0;
	
	bool traffic, tr_car, tr_station;
	bool crash, crash_car, crash_station;
	bool work_in_progress, wip_car, wip_station;
	bool sos, sos_car, sos_station;
	bool mes_from_broad;
	bool next_station_problem;
	uint16_t mes_station_involved, mes_station;
	
	uint16_t crashed_car = 0;
	uint8_t count_car_before_st_mex = NUM_MAX_FOR_STATION_PROBLEM;
	
	message_t pkt;
	message_t broad;
	MyPayload* streetState;
	MyPayload* pktReceivedFromCar;
	Car current_car;
	Car buffer_cars[NUM_MAX_CAR];

	//TASKS
	task void trafficControl(){
		uint8_t i = 0, a = 0, count_car_traffic = 0;
		uint8_t id_founded_car = 0;
		
		for (i=0; i<NUM_MAX_CAR && buffer_cars[i].car_id > 0; i++){
			for (a=i+1; a<NUM_MAX_CAR && buffer_cars[a].car_id > 0; a++){
				if (buffer_cars[i].car_id == buffer_cars[a].car_id && crashed_car != buffer_cars[i].car_id){
					id_founded_car = buffer_cars[i].car_id;
					count_car_traffic++;
					if (count_car_traffic >= NUM_CAR_MIN_TRAFFIC){
						printf("Traffico!\n");
						tr_car = TRUE;
						return;
					}
					break;
				}
			}
			id_founded_car = 0;
		}
		tr_car = FALSE;
		printfflush();
		return;
	}
	
	task void incidentControl(){
		uint8_t i;
		for (i=0; i<NUM_MAX_CAR && buffer_cars[i].car_id > 0; i++)
			if(buffer_cars[i].car_id == crashed_car){
				printf("Incidente\n");
				crash_car = TRUE;
				return;
			}
		crash_car = FALSE;
		crashed_car = 0;
		return;
	}
	
	//EVENTS
	event void Boot.booted(){
		call Radio.start();
		traffic = FALSE;
		crash = FALSE;
		work_in_progress = FALSE;
		sos = FALSE;
		next_station_problem = FALSE;
		mes_station_involved = 0;
		
		call TimerBroadcast.startPeriodic(PERIOD_BROADCAST);
		call TimerStation.startPeriodic(PERIOD_INTERCOMUNICATION);
	}
		
	event void Radio.startDone(error_t code){
	}
	
	event void Radio.stopDone(error_t code){
	}
	
	event void AMSend.sendDone(message_t* msg, error_t code){
	}
	
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength){
		if (payloadLength == sizeof(MyPayload)){
			pktReceivedFromCar = (MyPayload*)payload;
			
			//If it's station's message:
			if((pktReceivedFromCar->myNodeid == TOS_NODE_ID + 1) && !mes_from_broad){
				count_car_before_st_mex = NUM_MAX_FOR_STATION_PROBLEM;
				tr_station = pktReceivedFromCar->traffic;
				crash_station = pktReceivedFromCar->crash;
				wip_station = pktReceivedFromCar->work_in_progress;
				sos_station = pktReceivedFromCar->sos;
				next_station_problem = pktReceivedFromCar->next_station_problem;
				mes_station = pktReceivedFromCar->mes_station_involved;
			}
			
			//If it's car's message:
			if((pktReceivedFromCar->myNodeid > MIN_ID_CAR) && (pktReceivedFromCar->myNodeid < MAX_ID_CAR)){
				count_car_before_st_mex--;
				current_car.car_id = pktReceivedFromCar->myNodeid;
				current_car.crash = pktReceivedFromCar->crash;
				current_car.sos = pktReceivedFromCar->sos;
				sos_car = current_car.sos;
				
				//Special ID for change work in progress
				if(pktReceivedFromCar->myNodeid == ID_FOR_CHANGE_WORK)
					wip_car = pktReceivedFromCar->work_in_progress;
				else{//Insert car into the buffer
					wip_car = work_in_progress;
					buffer_cars[j] = current_car;
					j++;
					j = j % NUM_MAX_CAR;
				}
			}
			
			traffic = tr_station;
			crash = crash_station;
			work_in_progress = wip_station;
			sos = sos_station;
			mes_station_involved = mes_station;
			
			post trafficControl();

			if(current_car.crash)
				crashed_car = current_car.car_id;
				
			post incidentControl();
			
			if(!(sos_station)){
				if (tr_car || crash_car || sos_car || wip_car){
					traffic = tr_car;
					crash = crash_car;
					work_in_progress = wip_car;
					sos = sos_car;
					mes_station_involved = TOS_NODE_ID;
				}
				else
					if(!(tr_station || crash_station || wip_station))
						mes_station_involved = 0;
			}

			if(count_car_before_st_mex<0){
				next_station_problem = TRUE;
				mes_station_involved = TOS_NODE_ID + 1;
			}else
				next_station_problem = FALSE;
		}
		return msg;
	}

	event void TimerBroadcast.fired(){
		streetState = (MyPayload*)(call Packet.getPayload( &broad, sizeof(MyPayload)));
		streetState->myNodeid = TOS_NODE_ID;
		streetState->traffic = traffic;
		streetState->crash = crash;
		streetState->work_in_progress = work_in_progress;
		streetState->sos = sos;
		streetState->next_station_problem = FALSE;
		streetState->broad = TRUE;
		streetState->mes_station_involved = mes_station_involved;
		call AMSend.send(ID_BROADCAST, &broad, sizeof(MyPayload));
	}
	
	event void TimerStation.fired(){
		streetState = (MyPayload*)(call Packet.getPayload( &broad, sizeof(MyPayload)));
		streetState->myNodeid = TOS_NODE_ID;
		streetState->traffic = traffic;
		streetState->crash = crash;
		streetState->work_in_progress = work_in_progress;
		streetState->sos = sos;
		streetState->next_station_problem = next_station_problem;
		streetState->broad = FALSE;
		streetState->mes_station_involved = mes_station_involved;
		call AMSend.send(TOS_NODE_ID - 1, &pkt, sizeof(MyPayload));
	}
}

#include <UserButton.h>
#include "Message.h"
#include "Car_message.h"
#include "printf.h"

#define BLUETOOTH_TIMER 1000
#define WRITE_TIMER 15000
#define RADIO_TIMER 30000
#define MIN_ID_CAR 20
#define MAX_ID_CAR 200
#define NUM_CAR_MIN_TRAFFIC 2
#define ID_FOR_CHANGE_WORK 199

module StazioneBluetoothC {
  uses {
    interface Boot;
    interface Leds;
    interface Init as BluetoothInit;
    interface StdControl as BTStdControl;
    interface Bluetooth;
    interface Timer<TMilli> as activityTimer;
    interface Timer<TMilli> as ResetTimer;
    interface Timer<TMilli> as RadioTimer;
    interface SplitControl as Radio;
    interface Packet;
    interface AMSend;
    interface Receive;
  }
}

implementation {
  uint8_t j = 0;

  uint16_t myNodeid, id_corr, crashed_car;
  bool traffic, tr_car, tr_station;
  bool crash, crash_car, crash_station;
  bool work_in_progress, wip_car, wip_station;
  bool sos, sos_car, sos_station;
  bool mes_from_broad;
  uint16_t mes_station_involved, mes_station;

  uint16_t idAutoInc = 0;
  int static counttra = 0;
  int static countlav = 0;
  int static countinc = 0;
  message_t pkt;
  message_t broad;
  MyPayload* streetState;
  MyPayload* pktReceivedFromCar;
  Auto current_car;
  Auto buffer_cars[NUM_MAX_CAR];
  bool connected = FALSE;
  char buffer[20];

  event void Boot.booted() { 
    call BluetoothInit.init();
    call Bluetooth.setRadioMode(SLAVE_MODE); 
    call Bluetooth.setName("Shimmerfra"); 
    call BTStdControl.start();
    strcpy(buffer, "HighwaySense\r\n");
    connected = TRUE;
    call activityTimer.startPeriodic(BLUETOOTH_TIMER); 
    call ResetTimer.startOneShot(WRITE_TIMER);
    call RadioTimer.startOneShot(RADIO_TIMER);    
  }

  // TASKS
  task void trafficControl() {
    uint8_t i = 0, a = 0, count_car_traffic = 0;
    uint8_t id_founded_car = 0;
    
    for (i = 0; i < NUM_MAX_CAR && buffer_cars[i].car_id > 0; i++) {
      for (a = i + 1; a < NUM_MAX_CAR && buffer_cars[a].car_id > 0; a++) {
        if (buffer_cars[i].car_id == buffer_cars[a].car_id && crashed_car != buffer_cars[i].car_id) {
          id_founded_car = buffer_cars[i].car_id;
          count_car_traffic++;
          if (count_car_traffic >= NUM_CAR_MIN_TRAFFIC) {
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

  task void incidentControl() {
    uint8_t i;
    for (i = 0; i < NUM_MAX_CAR && buffer_cars[i].car_id > 0; i++)
      if (buffer_cars[i].car_id == crashed_car) {
        printf("Incidente\n");
        crash_car = TRUE;
        return;
      }
    crash_car = FALSE;
    crashed_car = 0;
    return;
  }

  task void sendStuff() {
    char localbuffer[100]; 
    int len;

    if ((work_in_progress == 1 && countlav < 3) ||
        (crash == 1 && countinc < 3) ||
        (traffic == 1 && counttra < 3)) {
      
      sprintf(localbuffer, " Attenzione ");
      if (work_in_progress == 1 && countlav < 3) {
        strcat(localbuffer, " ci sono lavori in corso\r\n");
        countlav += 1;
      }
      if (crash == 1 && countinc < 3) {
        strcat(localbuffer, " c'è un crash\r\n");
        countinc += 1;
      }
      if (traffic == 1 && counttra < 3) {
        strcat(localbuffer, " possibile traffic ");
        counttra += 1;
      }

      strcat(localbuffer, "piu avanti, fare attenzione!\r\n");
      call Bluetooth.write((const uint8_t *)localbuffer, strlen(localbuffer));
    }

    len = sprintf(localbuffer, 
                  "MyNode: %d, Traf: %d, Inc: %d, Lav: %d, Sos: %d, Palo: %d\r\n", 
                  TOS_NODE_ID, traffic, crash, work_in_progress, sos, mes_station_involved);

    if (len > 0 && len < sizeof(localbuffer)) {
      if (connected) {
        if (call Bluetooth.write((const uint8_t *)localbuffer, strlen(localbuffer)) == SUCCESS) {
          call Leds.led1Toggle();
        } else {
          call Leds.led0On();
        }
      }
    } else {
      call Leds.led2On();
    }
  }

  event void ResetTimer.fired() {
    counttra = 0;
    countlav = 0;
    countinc = 0;
    call ResetTimer.startOneShot(WRITE_TIMER); 
  }

  event void RadioTimer.fired() {
    call BTStdControl.stop();
    call Radio.start();
    streetState = (MyPayload*)(call Packet.getPayload(&broad, sizeof(MyPayload)));
    streetState->myNodeid = TOS_NODE_ID;
    streetState->traffic = traffic;
    streetState->crash = crash;
    streetState->work_in_progress = work_in_progress;
    streetState->sos = sos;
    streetState->broad = TRUE;
    streetState->mes_station_involved = mes_station_involved;
    call AMSend.send(ID_BROADCAST, &broad, sizeof(MyPayload));
    call RadioTimer.startOneShot(RADIO_TIMER); 
  }

  event void activityTimer.fired() {
    call Radio.stop();
    call BTStdControl.start();
    post sendStuff();  
  }

  async event void Bluetooth.connectionMade(uint8_t status) { 
    call Leds.led0On();  
    call Leds.led2Off();  
  }

  async event void Bluetooth.connectionClosed(uint8_t reason) {
    connected = FALSE;  
    call activityTimer.stop(); 
    call Bluetooth.write((const uint8_t *)"Disconnected!\r", 14);
  }

  async event void Bluetooth.dataAvailable(uint8_t data) {
    call Leds.led1Toggle();
  }

  event void Bluetooth.writeDone() {
    call Leds.led1Toggle();
  }

  async event void Bluetooth.commandModeEnded() { 
    call Leds.led0On();
  }

  event void Radio.startDone(error_t code) {
    if (code == SUCCESS) {
      call Leds.led1On();
    } else {
      printf("errore\n");
    }
  }

  event void Radio.stopDone(error_t code) {
    if (code == SUCCESS) {
      call BluetoothInit.init();
      call Bluetooth.setRadioMode(SLAVE_MODE); 
      call Bluetooth.setName("Shimmerfra"); 
      call BTStdControl.start();
      printf("con successo\n");
      call Leds.led1Off();
    } else {
      printf("errore\n");
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t code) {
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t payloadLength) {
    if (payloadLength == sizeof(MyPayload)) {
      pktReceivedFromCar = (MyPayload*)payload;
      
      // If it's station's message:
      if ((pktReceivedFromCar->myNodeid == TOS_NODE_ID + 1) && !mes_from_broad) {
        tr_station = pktReceivedFromCar->traffic;
        crash_station = pktReceivedFromCar->crash;
        wip_station = pktReceivedFromCar->work_in_progress;
        sos_station = pktReceivedFromCar->sos;
        mes_station = pktReceivedFromCar->mes_station_involved;
      }
      
      // If it's car's message:
      if ((pktReceivedFromCar->myNodeid > MIN_ID_CAR) && (pktReceivedFromCar->myNodeid < MAX_ID_CAR)) {
        current_car.car_id = pktReceivedFromCar->myNodeid;
        current_car.crash = pktReceivedFromCar->crash;
        current_car.sos = pktReceivedFromCar->sos;
        sos_car = current_car.sos;
        
        // Special ID for change work in progress
        if (pktReceivedFromCar->myNodeid == ID_FOR_CHANGE_WORK)
          wip_car = pktReceivedFromCar->work_in_progress;
        else { // Insert car into the buffer
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

      if (current_car.crash)
        crashed_car = current_car.car_id;
      
      post incidentControl();
      
      if (!(sos_station)) {
        if (tr_car || crash_car || sos_car || wip_car) {
          traffic = tr_car;
          crash = crash_car;
          work_in_progress = wip_car;
          sos = sos_car;
          mes_station_involved = TOS_NODE_ID;
        } else {
          mes_station_involved = 0;
        }
      }
    }
    return msg;
  }
}

#ifndef MESSAGE_H
#define MESSAGE_H

enum {MESSAGE_TYPE = 20};

typedef nx_struct MyPayload {
	nx_uint16_t myNodeid;
	nx_bool traffic;
	nx_bool crash;
	nx_bool work_in_progress;
	nx_bool sos;
	nx_bool broad;
	nx_bool next_station_problem;
	nx_uint16_t mes_station_involved;
} MyPayload;

#endif
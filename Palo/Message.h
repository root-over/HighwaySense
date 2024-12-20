#ifndef MESSAGE_H
#define MESSAGE_H

enum {MESSAGE_TYPE = 20};

typedef nx_struct MyPayload {
	nx_uint16_t myNodeid;
	nx_bool traffico;
	nx_bool incidente;
	nx_bool lavori_in_corso;
	nx_uint16_t mes_Aggiuntivo;
} MyPayload;

typedef struct Auto {
	uint16_t autoid;
	bool traffico;
	bool incidente;
	bool lavori_in_corso;
    char targa[8];
} Auto;

#endif

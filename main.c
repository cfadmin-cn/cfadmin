#include "stdio.h"
#include "stdlib.h"

// #define EV_MULTIPLICITY 0
#define EV_FEATURES (1 | 2 | 8 | 16 | 32 | 64)

#include "ev.h"


int main(int argc, char const *argv[])
{
	ev_default_loop(0);

	// ev_run(0);

	printf("%d\n", ev_backend());
	
	return 0;
}
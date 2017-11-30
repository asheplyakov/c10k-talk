=======================================
c10k problem and reactor design pattern
=======================================

Synopsis
========

* `Disclaimer`_
* `Introduction: legacy approach to concurrency`_
* `Four horsemen of performance apocalypse`_ 
   - `Demo: multithreaded tftp server versus 100+ clients`_
* `C10k aware design principles`_
* `Readiness notification: epoll`_
* `Kernel based load balancing: SO_REUSEPORT`_
* `Classical text`_


Disclaimer
==========

This talk is neither new nor original. It's better to read the `Classical text`_.


Introduction: legacy approach to concurrency
============================================

Any interaction between a client and a server can be represented as
a state machine.

If there are several clients simultaneously interacting
with the server the state machine gets more complicated. The easiest
way to avoid the complexity is to make a per client copy of the 
"single client" state machine, i.e. fork a process (or a thread
per process). This used to work just fine for some time when 

* networks used to be small (20 -- 100 nodes)
* communication links used to be slow (like 10Mb ethernet)
* CPUs were simple so the cost of a context switch was relatively low

That "golden age" has long since gone. Now

* there are billions of devices connected to the Internet
* 10Gb uplinks are quite common
* CPUs have lots of registers, caches (L1, L2, TLB, you name it),
  and switching between processes/threads is prohibitively slow


Four horsemen of performance apocalypse
=======================================

* Context switches
* Lock contention
* Memory allocation
* Data copies

A "thread/process per a client" model results in all of the above problems

Demo: multithreaded TFTP server versus 100+ clients
---------------------------------------------------

Transfering a 1KB file via TFTP looks like this:

+-----------------------------+-----------------------------+
| TFTP client                 |  TFTP server                |
+=============================+=============================+
| RRQ filename dst_port=69    | DATA block=1 src_port=12345 |
+-----------------------------+-----------------------------+
| ACK block=1  dst_port=12345 | DATA block=2 src_port=12345 |
+-----------------------------+-----------------------------+

::

  ansible-playbook -K -i playbooks/hosts playbooks/site.yml
  ./scripts/run_atftpd.sh         # in one screen
  ./scripts/run_clients.sh -c 100 # all clients complete successfully
  ./scripts/run_clients.sh -c 200 # many clients timed out
  kill -15 `pgrep atftpd`

The same machine can serve even more clients with a properly designed TFTP server::

  ./scripts/run_async.sh
  ./scripts/run/clients.sh -c 300 # all clients complete successfully


C10K aware design principles
============================

* Serve many clients with each thread, and use
 
  - non-blocking IO and level-triggered readiness notification
  - non-blocking IO and readiness change notification
  - asynchronous I/O (not popular in UNIX)

* Use the kernel facilities to dispatch the load between the server threads

  - SO_REUSEPORT

* Avoid using threads for concurrency, use cooperative multitasking
  when appropriate (coroutines/green threads)

  - concurrency: composition of independently executing tasks
  - parallelism: simultaneous execution of (possibly related) tasks


Readiness notification: epoll
=============================

* Stateful: no need to pass all 10k+ sockets to the syscall every time
* Therefore can provide readiness change notification
* User data can be inserted into ``epoll_event``

Initialize the event loop::

  int epfd = epoll_create1(EPOLL_CLOEXEC);

Subscribe for the notifications::

  struct client {
    int sock;
    unsigned bufsz;
    char *buf;
  };

  struct epoll_event ev;
  ev.events = EPOLLIN;
  ev.data.ptr = client;
  if (epoll_ctl(epfd, EPOLL_CTL_ADD, client->sock, &ev) < 0) {
      perror("epoll_ctl");
      return -1;
  }

Wait for events::

  struct epoll_events events[EVENT_COUNT];
  int nfired;
  if ((nfired = epoll_wait(epfd, events, EVENT_COUNT, -1)) > 0) {
     // process events
  }

Terminate the event loop::

  close(epfd);

Notes: 

* timers, signals, notifications from other threads can be processed
  in the same way, see timerfd_, signalfd_, eventfd_
* Non-blocking IO/readiness notification does not work with ordinary files


.. _timerfd: http://man7.org/linux/man-pages/man2/timerfd_create.2.html
.. _signalfd: http://man7.org/linux/man-pages/man2/signalfd.2.html
.. _eventfd: http://man7.org/linux/man-pages/man2/eventfd.2.html


Kernel based load balancing: SO_REUSEPORT
==========================================

``SO_REUSEADDR``: bind(2) allows reusing local addresses. That is,
if there's a TCP socket in ``TIME_WAIT`` state bound to 0.0.0.0:X
it's still possible to bind to port X.

``SO_REUSEPORT`` allows multiple TCP (UDP) sockets on the same host to
bind to the same port (`LWN article`_). With TCP this allows multiple
listening sockets (normally each in a different thread) to be bound
to the same port. Each thread can accept() incoming connections without
disrupting others. Most importantly the kernel will evenly distribute
incoming connections between threads.

Before ``SO_REUSEPORT`` multiple threads could accept() on the same socket,
however

* any incoming connection wakes up all threads, and only one of them can
  make a progress, while others get blocked immediately (known as
  `thundering herd problem`_)
* under high load the distribution of incoming connections between threads
  is very far from fair

Advanced load balancing is possible with ``SO_ATTACH_BPF`` (`Attaching
eBPF programs to sockets`_).

.. _LWN article: https://lwn.net/Articles/542629
.. _thundering herd problem: https://en.wikipedia.org/wiki/Thundering_herd_problem
.. _Attaching eBPF programs to sockets: https://lwn.net/Articles/625224


Classical text
==============

* `The c10k problem`_

.. _The c10k problem: http://www.kegel.com/c10k.html

int main(void)
{
    volatile int a = 10;
    volatile int b = 20;
    volatile int c;

    c = a + b;
    c = c - 5;

    while (1);

    return 0;
}

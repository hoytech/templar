#include <iostream>
#include <vector>

#include "mytmpls.h"

int main() {
    struct {
        std::string attr = "isn't it \n <great>?";
        std::string contents = "hello 'doug'! <>";
        std::string danger = "<h2>DANGER</h2>";
        int num = 123;

        struct {
            std::string header = "MYHEAD > \"'123'\" < inf";
        } info;

        std::vector<double> items = {1.1, 2.2, 3.3};
        bool showSomething = false;
    } stuff;

    std::cout << tmpl::frame(stuff).str << std::endl;
}

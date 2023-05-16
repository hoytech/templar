#include <iostream>
#include <vector>

#include "mytmpls.h"

int main() {
    struct {
        std::string attr = "isn't it \n grand?";
        std::string contents = "hello 'doug'! <>";
        int num = 123;

        struct {
            std::string header = "MYHEAD > 123";
        } info;

        std::vector<double> items = {1.1, 2.2, 3.3};
        bool showSomething = false;
    } stuff;

    std::cout << tmpl::frame(stuff) << std::endl;
}

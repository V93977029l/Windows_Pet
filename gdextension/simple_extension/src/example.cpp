#include "example.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <cstdio>

namespace godot {

Example::Example() {
    printf("Example created!\n");
}

Example::~Example() {
    printf("Example destroyed!\n");
}

void Example::set_value(int p_value) {
    value = p_value;
}

int Example::get_value() const {
    return value;
}

void Example::say_hello() {
    printf("Hello from Example class!\n");
    printf("Current value: %d\n", value);
}

void Example::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_value", "value"), &Example::set_value);
    ClassDB::bind_method(D_METHOD("get_value"), &Example::get_value);
    ClassDB::bind_method(D_METHOD("say_hello"), &Example::say_hello);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "value"), "set_value", "get_value");
}

} // namespace godot
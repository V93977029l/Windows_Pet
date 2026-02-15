#ifndef EXAMPLE_H
#define EXAMPLE_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class Example : public Node {
    GDCLASS(Example, Node);

private:
    int value = 0;

protected:
    static void _bind_methods();

public:
    Example();
    ~Example();

    void set_value(int p_value);
    int get_value() const;
    void say_hello();
};

} // namespace godot

#endif // EXAMPLE_H
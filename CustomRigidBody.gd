extends RigidBody

class_name CustomRigidBody

signal on_integrate_forces

func _integrate_forces(state):
	emit_signal("on_integrate_forces", state, self)


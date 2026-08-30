extends SceneTree

# Placeholder replaced in the same implementation pass after the active runtime
# seam has been verified. Kept intentionally failing until the production fix is
# committed so the regression cannot be accidentally omitted.

func _initialize() -> void:
    assert(false, "Status speed soft-cap regression test not implemented yet.")
    quit(1)

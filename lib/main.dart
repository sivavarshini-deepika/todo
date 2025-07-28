import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const TodoApp());
}

class Todo {
  Todo({
    required this.id,
    required this.title,
    required this.dueDate,
    this.isDone = false,
  });

  final String id;
  String title;
  DateTime? dueDate;
  bool isDone;
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To‑Do',
      theme: ThemeData(
        colorSchemeSeed: Colors.purple,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const TodoHomePage(),
    );
  }
}

enum Filter { all, active, completed }

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<Todo> _todos = [
    Todo(
      id: UniqueKey().toString(),
      title: 'An example task',
      dueDate: DateTime.now().add(const Duration(days: 1)),
    ),
  ];

  Filter _filter = Filter.all;
  Todo? _recentlyDeleted; // for undo

  int get _completedCount => _todos.where((t) => t.isDone).length;

  List<Todo> get _visibleTodos {
    switch (_filter) {
      case Filter.active:
        return _todos.where((t) => !t.isDone).toList();
      case Filter.completed:
        return _todos.where((t) => t.isDone).toList();
      case Filter.all:
      default:
        return _todos;
    }
  }

  void _addOrEditTodo({Todo? editing}) async {
    final result = await showModalBottomSheet<_TodoFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TodoFormSheet(initial: editing),
    );

    if (result == null) return;

    setState(() {
      if (editing == null) {
        _todos.add(Todo(
          id: UniqueKey().toString(),
          title: result.title,
          dueDate: result.dueDate,
        ));
      } else {
        editing.title = result.title;
        editing.dueDate = result.dueDate;
      }
    });
  }

  void _toggleDone(Todo todo, bool? value) {
    setState(() {
      todo.isDone = value ?? false;
    });
  }

  void _deleteTodo(Todo todo) {
    setState(() {
      _recentlyDeleted = todo;
      _todos.remove(todo);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            if (_recentlyDeleted != null) {
              setState(() {
                _todos.add(_recentlyDeleted!);
                _recentlyDeleted = null;
              });
            }
          },
        ),
      ),
    );
  }

  void _clearCompleted() {
    final removed = _todos.where((t) => t.isDone).toList();
    if (removed.isEmpty) return;

    setState(() {
      _todos.removeWhere((t) => t.isDone);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.length} completed task(s) cleared'),
      ),
    );
  }

  String _filterLabel(Filter f) {
    switch (f) {
      case Filter.all:
        return 'All';
      case Filter.active:
        return 'Active';
      case Filter.completed:
        return 'Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completedCount;
    final total = _todos.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('To‑Do App'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Clear completed',
            onPressed: completed == 0 ? null : _clearCompleted,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditTodo(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: SafeArea(
        child: Column(
          children: [
          // header card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _HeaderCard(completed: completed, total: total),
            ),

            // filter row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<Filter>(
                segments: Filter.values
                    .map((f) => ButtonSegment<Filter>(
                          value: f,
                          label: Text(_filterLabel(f)),
                          icon: f == Filter.all
                              ? const Icon(Icons.list)
                              : f == Filter.active
                                  ? const Icon(Icons.radio_button_unchecked)
                                  : const Icon(Icons.check_circle_outline),
                        ))
                    .toList(),
                selected: {_filter},
                onSelectionChanged: (s) {
                  setState(() {
                    _filter = s.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _visibleTodos.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _visibleTodos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final todo = _visibleTodos[index];
                        return Dismissible(
                          key: ValueKey(todo.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete task?'),
                                    content: const Text(
                                        'This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('CANCEL'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('DELETE'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                            return ok;
                          },
                          onDismissed: (_) => _deleteTodo(todo),
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: _TodoTile(
                            todo: todo,
                            onChanged: (v) => _toggleDone(todo, v),
                            onEdit: () => _addOrEditTodo(editing: todo),
                            onDelete: () => _deleteTodo(todo),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : completed / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$completed of $total tasks completed',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent.toDouble(),
            borderRadius: BorderRadius.circular(12),
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.todo,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final Todo todo;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final due = todo.dueDate;
    final isOverdue =
        due != null && !todo.isDone && due.isBefore(DateTime.now());
    final dateText =
        due == null ? 'No due date' : DateFormat.yMMMd().format(due);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: todo.isDone,
                onChanged: onChanged,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              decoration: todo.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isOverdue
                                  ? Colors.red
                                  : Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withOpacity(.7),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No tasks here.\nTap “Add Task” to create one!',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color:
                  Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(.6),
            ),
      ),
    );
  }
}

/// ----------  Add/Edit Sheet  ----------

class _TodoFormResult {
  _TodoFormResult(this.title, this.dueDate);

  final String title;
  final DateTime? dueDate;
}

class TodoFormSheet extends StatefulWidget {
  const TodoFormSheet({super.key, this.initial});

  final Todo? initial;

  @override
  State<TodoFormSheet> createState() => _TodoFormSheetState();
}

class _TodoFormSheetState extends State<TodoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _titleCtrl.text = widget.initial!.title;
      _dueDate = widget.initial!.dueDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _TodoFormResult(_titleCtrl.text.trim(), _dueDate));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottom + 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.initial == null ? 'Add Task' : 'Edit Task',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Task title *',
                hintText: 'e.g. Buy groceries',
              ),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Title is required';
                if (text.length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _dueDate == null
                          ? 'Pick due date (optional)'
                          : DateFormat.yMMMd().format(_dueDate!),
                    ),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    tooltip: 'Clear date',
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.initial == null ? 'Add' : 'Save'),
            ),
          ],
        ),
     ),
     );
}
}
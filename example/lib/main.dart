import 'package:flutter/material.dart';
import 'package:listen_it/listen_it.dart';
import 'package:listen_it_example/model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'listen_it Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'listen_it Demo'),
    );
  }
}

/// I didn't want to use any Locator or InheritedWidget
/// in this example. In a real project I wouldn't use
/// a global variable for this.
final theModel = Model();

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Type any value here'),
              const SizedBox(height: 16),
              TextField(
                onChanged: theModel.updateText,
              ),
              const SizedBox(height: 16),
              const Text(
                  'The following field displays the entered text in uppercase.\n'
                  'It gets only updated if the user pauses its input for at least 500ms'),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ValueListenableBuilder<String>(
                    valueListenable: theModel.debouncedUpperCaseText,
                    builder: (context, s, _) => Text(s),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This counter only displays even Numbers',
                textAlign: TextAlign.center,
              ),
              ValueListenableBuilder<String>(
                valueListenable: theModel.counterEvenValuesAsString,
                builder: (context, value, _) => Text(value,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center),
              ),
              const Text(
                'The following field gets updated whenever one of the others changes:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                /// Simple example of `combineLatest` without a wrapper class
                /// because the combiner function combines both values to one single string
                valueListenable: theModel.debouncedUpperCaseText.combineLatest(
                    theModel.counterEvenValuesAsString, (s1, s2) => '$s1:$s2'),
                builder: (context, value, _) => Text(value,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: theModel.incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

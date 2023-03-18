import 'package:kepler_app/libs/state.dart';
import 'package:kepler_app/tabs/news/news_data.dart';
import 'package:workmanager/workmanager.dart';

const newsFetchTaskName = "fetch_news";

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void taskCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    if (task == newsFetchTaskName) {
      runNewsFetchTask();
    }
    return Future.value(true);
  });
}

Future<void> runNewsFetchTask() async {
  if (!newsCache.loaded || newsCache.newsData.isEmpty) return;
  final lastNewsLink = newsCache.newsData.first.link;
  final currentNews = await loadNews(0);
  if (currentNews == null || currentNews.isEmpty) return;
  if (lastNewsLink != currentNews.first.link) {
    final newNews = <NewsEntryData>[];
    var i = 0;
    while (currentNews[i].link != lastNewsLink && i < currentNews.length) {
      newNews.add(currentNews[i]);
      i++;
    }
    // TODO: notification on newNews with https://pub.dev/packages/flutter_local_notifications
  }
}

// The study desk, drawn: honey oak, raspberry book cloth, ruled index cards and stacks of them, rubber stamps, the
// date-due slip. Plain C on CoreGraphics and CoreText, so tests/preview.c renders the same pixels on the Mac. Every
// function draws into a y-down (UIKit-style) context in points, lit from above, in Helvetica.
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <stdint.h>

extern CGFloat CDShadowSign;   // +1 on iOS, where a positive shadow height falls downward; the Mac preview sets -1

// the index card, in points; the web view's CSS lines its text up on these rules
#define CD_CARD_W 296
#define CD_CARD_H 188
#define CD_CARD_HEADER 32      // the red line
#define CD_CARD_FIRST_RULE 52  // the first blue line
#define CD_CARD_RULE 20        // between blue lines

void CDDrawOak(CGContextRef c, CGRect r, uint32_t seed, int vertical);   // vertical grain tiles seamlessly top to bottom
void CDDrawVignette(CGContextRef c, CGRect r);
void CDDrawCloth(CGContextRef c, CGRect r);                                // the navigation bar
void CDDrawIndexCard(CGContextRef c, CGRect r, uint32_t seed, int ruled);   // rules scale with the card's width
#define CD_STACK_W 150
#define CD_STACK_H 112
CGRect CDStackTopCard(CGRect r, uint32_t seed);                            // where the top card of a stack lies
void CDDrawStack(CGContextRef c, CGRect r, uint32_t seed, int cards);      // a deck: a few cards squared up by hand
CGSize CDBadgeSize(const char *text);
void CDDrawBadge(CGContextRef c, CGRect r, const char *text);             // the red count badge, as SpringBoard draws it
void CDDrawSectionHeader(CGContextRef c, CGRect r, const char *title);    // letterpressed into the desk between hairlines
void CDDrawCountTab(CGContextRef c, CGRect r, long fresh, long learning, long due);
void CDDrawStamp(CGContextRef c, CGRect r, int rating, int pressed);      // rating 1 Again .. 4 Easy; the interval is a UILabel on top
void CDDrawImpression(CGContextRef c, CGRect r, int rating, uint32_t seed);   // what a stamp leaves on a card

// Stats: paper sheets on the desk with charts on graph paper, in the stamp inks.
typedef struct {
    int answers[30][4];                // the last 30 days, oldest first, by rating (Again, Hard, Good, Easy)
    int forecast[30];                  // reviews due today (overdue included) and on each of the next 29 days
    int weekPass[12], weekTotal[12];   // the last 12 weeks, oldest first: reviews remembered, reviews made
    int states[4];                     // new, learning, young, mature
    int answersToday, minutesToday, streak, target;
    const char *answersFrom, *answersMid, *forecastMid, *forecastTo;   // date labels for the x axes
} CDChartData;
void CDDrawSheet(CGContextRef c, CGRect r, uint32_t seed);   // a sheet of paper on the desk; the charts draw onto one
void CDDrawSummary(CGContextRef c, CGRect r, const CDChartData *d);
void CDDrawAnswersChart(CGContextRef c, CGRect r, const CDChartData *d);
void CDDrawForecastChart(CGContextRef c, CGRect r, const CDChartData *d);
void CDDrawRetentionChart(CGContextRef c, CGRect r, const CDChartData *d);
void CDDrawStatesChart(CGContextRef c, CGRect r, const CDChartData *d);
void CDDrawTabIcon(CGContextRef c, CGRect r, int which);    // 0 decks, 1 stats: white on clear, for UITabBarItem's mask
void CDDrawTabBar(CGContextRef c, CGRect r);                // the empty bar, for the launch image

typedef struct {
    int npast; const char *pastDay[8]; int pastAnswers[8];   // the latest days studied, oldest first
    const char *nextDay[7]; int nextDue[7];                  // the coming week
    int answersToday, newToday, minutesToday, streak, retention, reviews30, target;   // retention -1 when there's none yet
    int cardsNew, cardsLearning, cardsYoung, cardsMature;
    int plainPocket;                                         // the pocket without the typed totals, when the charts above already give them
} CDStatsData;
CGFloat CDDateDueHeight(const CDStatsData *d);
void CDDrawDateDue(CGContextRef c, CGFloat width, const CDStatsData *d);   // the slip in its manila pocket

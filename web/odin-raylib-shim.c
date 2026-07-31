#include <stdbool.h>

typedef struct Vector2 { float x, y; } Vector2;
typedef struct Rectangle { float x, y, width, height; } Rectangle;
typedef struct Color { unsigned char r, g, b, a; } Color;

extern void BeginDrawing(void);
extern bool CheckCollisionPointRec(Vector2 point, Rectangle rec);
extern void ClearBackground(Color color);
extern void CloseWindow(void);
extern void DrawCircleV(Vector2 center, float radius, Color color);
extern void DrawLineEx(Vector2 start, Vector2 end, float thick, Color color);
extern void DrawRectangle(int x, int y, int width, int height, Color color);
extern void DrawRectangleRounded(Rectangle rec, float roundness, int segments, Color color);
extern void DrawRectangleRoundedLinesEx(Rectangle rec, float roundness, int segments, float line_thick, Color color);
extern void DrawText(const char *text, int x, int y, int font_size, Color color);
extern void DrawTriangle(Vector2 v1, Vector2 v2, Vector2 v3, Color color);
extern void EndDrawing(void);
extern float GetFrameTime(void);
extern Vector2 GetMousePosition(void);
extern int GetScreenHeight(void);
extern int GetScreenWidth(void);
extern int GetTouchPointCount(void);
extern Vector2 GetTouchPosition(int index);
extern void InitWindow(int width, int height, const char *title);
extern bool IsMouseButtonPressed(int button);
extern int MeasureText(const char *text, int font_size);
extern void SetConfigFlags(unsigned int flags);
extern void SetTargetFPS(int fps);
extern void SetWindowSize(int width, int height);

// Odin preserves the foreign-library name in relocatable WebAssembly symbols.
// These tiny C ABI wrappers connect those names to Raylib's ordinary exports.
#define ODIN_RAYLIB_SYMBOL(name) __asm__("wasm/libraylib.web.a.." #name)

#define WRAP_VOID_0(name) \
    void odin_##name(void) ODIN_RAYLIB_SYMBOL(name); \
    void odin_##name(void) { name(); }

WRAP_VOID_0(BeginDrawing)
WRAP_VOID_0(CloseWindow)
WRAP_VOID_0(EndDrawing)

bool odin_CheckCollisionPointRec(Vector2 point, Rectangle rec) ODIN_RAYLIB_SYMBOL(CheckCollisionPointRec);
bool odin_CheckCollisionPointRec(Vector2 point, Rectangle rec) { return CheckCollisionPointRec(point, rec); }

void odin_ClearBackground(Color color) ODIN_RAYLIB_SYMBOL(ClearBackground);
void odin_ClearBackground(Color color) { ClearBackground(color); }

void odin_DrawCircleV(Vector2 center, float radius, Color color) ODIN_RAYLIB_SYMBOL(DrawCircleV);
void odin_DrawCircleV(Vector2 center, float radius, Color color) { DrawCircleV(center, radius, color); }

void odin_DrawLineEx(Vector2 start, Vector2 end, float thick, Color color) ODIN_RAYLIB_SYMBOL(DrawLineEx);
void odin_DrawLineEx(Vector2 start, Vector2 end, float thick, Color color) { DrawLineEx(start, end, thick, color); }

void odin_DrawRectangle(int x, int y, int width, int height, Color color) ODIN_RAYLIB_SYMBOL(DrawRectangle);
void odin_DrawRectangle(int x, int y, int width, int height, Color color) { DrawRectangle(x, y, width, height, color); }

void odin_DrawRectangleRounded(Rectangle rec, float roundness, int segments, Color color) ODIN_RAYLIB_SYMBOL(DrawRectangleRounded);
void odin_DrawRectangleRounded(Rectangle rec, float roundness, int segments, Color color) { DrawRectangleRounded(rec, roundness, segments, color); }

void odin_DrawRectangleRoundedLinesEx(Rectangle rec, float roundness, int segments, float line_thick, Color color) ODIN_RAYLIB_SYMBOL(DrawRectangleRoundedLinesEx);
void odin_DrawRectangleRoundedLinesEx(Rectangle rec, float roundness, int segments, float line_thick, Color color) { DrawRectangleRoundedLinesEx(rec, roundness, segments, line_thick, color); }

void odin_DrawText(const char *text, int x, int y, int font_size, Color color) ODIN_RAYLIB_SYMBOL(DrawText);
void odin_DrawText(const char *text, int x, int y, int font_size, Color color) { DrawText(text, x, y, font_size, color); }

void odin_DrawTriangle(Vector2 v1, Vector2 v2, Vector2 v3, Color color) ODIN_RAYLIB_SYMBOL(DrawTriangle);
void odin_DrawTriangle(Vector2 v1, Vector2 v2, Vector2 v3, Color color) { DrawTriangle(v1, v2, v3, color); }

float odin_GetFrameTime(void) ODIN_RAYLIB_SYMBOL(GetFrameTime);
float odin_GetFrameTime(void) { return GetFrameTime(); }

Vector2 odin_GetMousePosition(void) ODIN_RAYLIB_SYMBOL(GetMousePosition);
Vector2 odin_GetMousePosition(void) { return GetMousePosition(); }

int odin_GetScreenHeight(void) ODIN_RAYLIB_SYMBOL(GetScreenHeight);
int odin_GetScreenHeight(void) { return GetScreenHeight(); }

int odin_GetScreenWidth(void) ODIN_RAYLIB_SYMBOL(GetScreenWidth);
int odin_GetScreenWidth(void) { return GetScreenWidth(); }

int odin_GetTouchPointCount(void) ODIN_RAYLIB_SYMBOL(GetTouchPointCount);
int odin_GetTouchPointCount(void) { return GetTouchPointCount(); }

Vector2 odin_GetTouchPosition(int index) ODIN_RAYLIB_SYMBOL(GetTouchPosition);
Vector2 odin_GetTouchPosition(int index) { return GetTouchPosition(index); }

void odin_InitWindow(int width, int height, const char *title) ODIN_RAYLIB_SYMBOL(InitWindow);
void odin_InitWindow(int width, int height, const char *title) { InitWindow(width, height, title); }

bool odin_IsMouseButtonPressed(int button) ODIN_RAYLIB_SYMBOL(IsMouseButtonPressed);
bool odin_IsMouseButtonPressed(int button) { return IsMouseButtonPressed(button); }

int odin_MeasureText(const char *text, int font_size) ODIN_RAYLIB_SYMBOL(MeasureText);
int odin_MeasureText(const char *text, int font_size) { return MeasureText(text, font_size); }

void odin_SetConfigFlags(unsigned int flags) ODIN_RAYLIB_SYMBOL(SetConfigFlags);
void odin_SetConfigFlags(unsigned int flags) { SetConfigFlags(flags); }

void odin_SetTargetFPS(int fps) ODIN_RAYLIB_SYMBOL(SetTargetFPS);
void odin_SetTargetFPS(int fps) { SetTargetFPS(fps); }

void odin_SetWindowSize(int width, int height) ODIN_RAYLIB_SYMBOL(SetWindowSize);
void odin_SetWindowSize(int width, int height) { SetWindowSize(width, height); }

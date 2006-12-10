
#ifndef __GTK_MINEFIELD_H__
#define __GTK_MINEFIELD_H__

#include <gdk/gdk.h>
#include <gtk/gtkwidget.h>
#include <glib.h>
#include <games-preimage.h>

#ifdef __cplusplus
extern "C" {
#endif				/* __cplusplus */

  enum {
    MINE_NOMARK = 0,
    MINE_MARKED,
    MINE_QUESTION
  };

/* Return valuse from the hint function. */
  enum {
    MINEFIELD_HINT_ACCEPTED,	/* We successfully revealed a single square. */
    MINEFIELD_HINT_NO_GAME,	/* The game hasn't started. */
    MINEFIELD_HINT_ALL_MINES	/* All the remaining squares are mines. */
  };


#define GTK_TYPE_MINEFIELD            (gtk_minefield_get_type ())
#define GTK_MINEFIELD(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), GTK_TYPE_MINEFIELD, GtkMineField))
#define GTK_MINEFIELD_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), GTK_TYPE_MINEFIELD, GtkMineFieldClass))
#define GTK_IS_MINEFIELD(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GTK_TYPE_MINEFIELD))
#define GTK_IS_MINEFIELD_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GTK_TYPE_MINEFIELD))
#define GTK_MINEFIELD_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), GTK_TYPE_MINEFIELD, GtkMineFieldClass))

  typedef struct _GtkMineField GtkMineField;
  typedef struct _GtkMineFieldClass GtkMineFieldClass;

  struct _Mine {
    guint mined:1;
    guint shown:1;
    guint marked:2;
    guint down:1;
    guint neighbours;
    guint neighbourmarks;
  };

  typedef struct _Mine mine;

  typedef struct _Sign sign;

  struct _Sign {
    GamesPreimage *preimage;
    GdkPixbuf *scaledpixbuf;

    gint width;
    gint height;
  };

  struct _GtkMineField {
    GtkWidget widget;
    guint xsize, ysize;
    guint mcount;
    mine *mines;
    guint flag_count;
    guint shown;
    gint cdown;
    guint cdownx;
    guint cdowny;
    gint bdown[3];
    gint lose;
    gint win;
    gint multi_mode;
    gint action;
    sign flag;
    sign mine;
    sign question;
    sign bang;
    sign warning;
    GRand *grand;
    GdkGC *thick_line;

    gboolean started;

    struct {
      PangoLayout *layout;
      gint dx, dy;
    } numstr[9];
    guint minesize;
    gint in_play;

    gboolean use_question_marks;
    gboolean use_overmine_warning;
    gboolean use_autoflag;
  };

  struct _GtkMineFieldClass {
    GtkWidgetClass parent_class;
    void (*marks_changed) (GtkMineField * mfield);
    void (*explode) (GtkMineField * mfield);
    void (*look) (GtkMineField * mfield);
    void (*unlook) (GtkMineField * mfield);
    void (*win) (GtkMineField * mfield);
    void (*hint_used) (GtkMineField * mfield);
  };

#define MINESIZE_MIN 12

  GType gtk_minefield_get_type (void);
  GtkWidget *gtk_minefield_new (void);

  void gtk_minefield_set_size (GtkMineField * mfield, guint xsize,
			       guint ysize);
  void gtk_minefield_restart (GtkMineField * mfield);
  void gtk_minefield_set_use_question_marks (GtkMineField * mfield,
					     gboolean use_question_marks);
  void gtk_minefield_set_use_overmine_warning (GtkMineField * mfield,
					       gboolean use_overmine_warning);
  void gtk_minefield_set_use_autoflag (GtkMineField * mfield,
				       gboolean use_autoflag);
  gint gtk_minefield_hint (GtkMineField * mfield);

#ifdef __cplusplus
}
#endif				/* __cplusplus */
#endif				/* __GTK_MINEFIELD_H__ */

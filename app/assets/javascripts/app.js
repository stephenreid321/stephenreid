
$(function () {

  $('[data-toggle="tooltip"]').tooltip()

  $('input[type=text].slug').each(function () {
    var slug = $(this);
    var start_length = slug.val().length;
    var pos = $.inArray(this, $('input', this.form)) - 1;
    var title = $($('input', this.form).get(pos));
    slug.focus(function () {
      slug.data('focus', true);
    });
    title.keyup(function () {
      if (start_length == 0 && slug.data('focus') != true)
        slug.val(title.val().toLowerCase().replace(/ /g, '-').replace(/[^a-z0-9\-]/g, ''));
    });
  });

  $("abbr.timeago").timeago()

  $('textarea.wysiwyg').each(function () {
    var textarea = this
    var editor = textboxio.replace(textarea, {
      css: {
        stylesheets: ['/stylesheets/app.css']
      },
      paste: {
        style: 'plain'
      },
      images: {
        allowLocal: false
      }
    });
    if (textarea.form)
      $(textarea.form).submit(function () {
        if ($(editor.content.get()).text().trim() == '')
          $(textarea).val(' ')
      })
  });

  $(document).on('click', 'a[data-confirm]', function (e) {
    var message = $(this).data('confirm');
    if (!confirm(message)) {
      e.preventDefault();
      e.stopped = true;
    }
  });

  $(document).on('click', 'a.popup', function (e) {
    window.open(this.href, null, 'scrollbars=yes,width=600,height=600,left=150,top=150').focus();
    return false;
  });

  $('.geopicker').geopicker({
    width: '100%',
    getLatLng: function (container) {
      var lat = $('input[name$="[lat]"]', container).val()
      var lng = $('input[name$="[lng]"]', container).val()
      if (lat.length && lng.length)
        return new google.maps.LatLng(lat, lng)
    },
    set: function (container, latLng) {
      $('input[name$="[lat]"]', container).val(latLng.lat());
      $('input[name$="[lng]"]', container).val(latLng.lng());
    }
  });

  $(document).on('submit', '[data-pagelet-url] form', function () {
    var form = this
    var pagelet = $(form).closest('[data-pagelet-url]')
    pagelet.css('opacity', '0.3')
    $.post($(form).attr('action'), $(form).serialize(), function () {
      pagelet.load(pagelet.attr('data-pagelet-url'), function () {
        pagelet.css('opacity', '1')
      })
    })
    return false
  })

  $(document).on('click', '[data-pagelet-url] a.pagelet-trigger', function () {
    var a = this
    var pagelet = $(a).closest('[data-pagelet-url]')
    pagelet.css('opacity', '0.3')
    $.get($(a).attr('href'), function () {
      pagelet.load(pagelet.attr('data-pagelet-url'), function () {
        pagelet.css('opacity', '1')
      })
    })
    return false
  })

  $('[data-pagelet-url]').each(function () {
    var pagelet = this;
    if ($(pagelet).html().length == 0)
      $(pagelet).load($(pagelet).attr('data-pagelet-url'))
  })

  $('[data-toggle="popover"]').popover({
    html: true,
    viewport: false,
    trigger: 'manual',
    placement: 'top',
    animation: false,
    title: function () {
      return $(this).next('span').html()
    },
    content: function () {
      return $(this).next('span').next('span').html()
    }
  }).on("mouseenter", function () {
    var _this = this;
    setTimeout(function () {
      if ($(_this).filter(':hover').length) {
        $(_this).popover("show");
        $($(_this).data('bs.popover')['tip']).on("mouseleave", function () {
          $(_this).popover('hide');
        });
      }
    }, 200);
  }).on("mouseleave", function () {
    var _this = this;
    setTimeout(function () {
      if (!$($(_this).data('bs.popover')['tip']).filter(':hover').length) {
        $(_this).popover("hide");
      }
    }, 200);
  });

});
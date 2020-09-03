$(function() {

  $("#lightgallery").lightGallery({
    showAfterLoad: false,
    thumbnail: true,
    selector: 'a'
  }).css({
    opacity: 0
  });

  $(".blog_post a[href^=http]").attr('target', '_blank')

  $('[data-toggle="tooltip"]').tooltip()

  $("abbr.timeago").timeago()

  $(document).on('click', 'a[data-confirm]', function(e) {
    var message = $(this).data('confirm');
    if (!confirm(message)) {
      e.preventDefault();
      e.stopped = true;
    }
  });

  $(document).on('click', 'a.popup', function(e) {
    window.open(this.href, null, 'scrollbars=yes,width=600,height=600,left=150,top=150').focus();
    return false;
  });

  $('.card').hover(function() {
    $('.showOnHover', this).addClass('d-sm-inline')
  }, function() {
    $('.showOnHover', this).removeClass('d-sm-inline')
  })

  var rangeSlider = function() {
    var slider = $('.range-slider'),
      range = $('.range-slider__range'),
      value = $('.range-slider__value');

    slider.each(function() {

      value.each(function() {
        var value = $(this).prev().attr('value');
        $(this).html(value);
      });

      range.on('input', function() {
        $(this).next(value).html(this.value);
      });
    });
  };

  rangeSlider();

});

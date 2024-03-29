(function ($) {
  $.fn.toc = function (options) {
    const settings = $.extend({
      container: 'body',
      selectors: 'h1, h2, h3, h4',
      activeClass: 'toc-active'
    }, options);

    return this.each(function () {
      const tocElement = $(this);
      let html = '<ul>';
      let headingIds = {};

      const headings = $(settings.container).find(settings.selectors).toArray();
      headings.sort((a, b) => a.offsetTop - b.offsetTop);

      headings.forEach((heading, index) => {
        const headingTag = heading.tagName.toLowerCase();
        const id = heading.id || `${headingTag}-${index}`;
        heading.id = id;
        if (!headingIds[headingTag]) {
          headingIds[headingTag] = [];
        }
        headingIds[headingTag].push(id);
        html += `<li class="toc-${headingTag}"><a href="#${id}">${heading.textContent}</a></li>`;
      });

      html += '</ul>';
      tocElement.html(html);

      tocElement.find('a').on('click', function (e) {
        e.preventDefault();
        const targetId = $(this).attr('href').substring(1);
        const targetElement = $('#' + targetId);
        if (targetElement.length) {
          const headerMarginTop = parseInt(targetElement.css('margin-top'), 10);
          $('html, body').animate({
            scrollTop: targetElement.offset().top - headerMarginTop + 1
          }, 1000);
        }
      });

      const highlightTOCOnScroll = () => {
        let scrollPosition = $(window).scrollTop();

        headings.forEach((heading, index) => {
          const headingTag = heading.tagName.toLowerCase();
          const id = heading.id;
          const headingElement = $('#' + id);
          const headerMarginTop = parseInt(headingElement.css('margin-top'), 10);
          const offsetTop = headingElement.offset().top - headerMarginTop;
          const nextHeadingElement = index < headings.length - 1 ? $('#' + headings[index + 1].id) : null;
          let offsetBottom = nextHeadingElement ? nextHeadingElement.offset().top - parseInt(nextHeadingElement.css('margin-top'), 10) : $(document).height();

          if (scrollPosition >= offsetTop && scrollPosition < offsetBottom) {
            tocElement.find('li').removeClass(settings.activeClass);
            tocElement.find(`a[href="#${id}"]`).parent().addClass(settings.activeClass);
          }
        });
      };

      $(window).on('scroll', highlightTOCOnScroll);
    });
  };
}(jQuery));



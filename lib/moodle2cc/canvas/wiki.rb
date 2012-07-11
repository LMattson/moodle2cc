module Moodle2CC::Canvas
  class Wiki < Moodle2CC::CC::Wiki
    attr_accessor :pages

    def initialize(mod)
      super
      page_versions = mod.pages.inject({}) do |result, page|
        version = result[page.page_name]
        result[page.page_name] = page.version if version.nil? || page.version > version
        result
      end

      @pages = mod.pages.map do |page|
        if page.version == page_versions[page.page_name]
          body = page.content
          body.gsub!(/\[(.*?)\]/) do |match|
            slug = file_slug(match)
            href = File.join(CGI.escape(WIKI_TOKEN), 'wiki', slug)
            %(<a href="#{href}" title="#{$1}">#{$1}</a>)
          end
          title_slug = file_slug(@title)
          slug = [title_slug, file_slug(page.page_name)].join('-')
          href = "#{WIKI_FOLDER}/#{slug}.html"
          OpenStruct.new(:title => page.page_name, :body => body, :href => href, :identifier => create_key(href))
        end
      end.compact

      if @pages.empty?
        slug = file_slug(@title)
        href = File.join(WIKI_FOLDER, "#{slug}.html")
        @pages = [OpenStruct.new(:title => @title, :body => mod.summary, :href => href, :identifier => create_key(href))]
      end

      @identifier = root_page.identifier
    end

    def self.create_resource_key(mod)
      Wiki.new(mod).identifer
    end

    def root_page
      @pages.find { |page| page.title == @title }
    end

    def create_resource_node(resources_node)
      @pages.each do |page|
        href = page.href
        resources_node.resource(
          :href => href,
          :type => WEBCONTENT,
          :identifier => create_key(href)
        ) do |resource_node|
          resource_node.file(:href => href)
        end
      end
    end

    def create_files(export_dir)
      create_html(export_dir)
    end

    def create_html(export_dir)
      template = File.expand_path('../templates/wiki_content.html.erb', __FILE__)
      @pages.each do |page|
        path = File.join(export_dir, page.href)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, 'w') do |file|
          erb = ERB.new(File.read(template))
          file.write(erb.result(page.instance_eval { binding }))
        end
      end
    end

    def create_module_meta_item_elements(item_node)
      item_node.content_type 'WikiPage'
      item_node.identifierref @identifier
    end
  end
end

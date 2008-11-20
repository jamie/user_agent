class UserAgent
  VERSION = '0.0.1'
  
  attr_reader :browser_name, :browser_version
  attr_reader :os_name, :os_version
  
  def initialize(user_agent)
    @user_agent = user_agent
    return if @user_agent.nil?
    extract_products_from_agent_string
    return if @products.empty?

    identify_browser
    identify_os
  end
  
  def browser
    [browser_name, browser_version].compact.join(' ')
  end
  
  def os
    [os_name, os_version].compact.join(' ')
  end
  
private
  def extract_products_from_agent_string
    pattern = Regexp.new(
      "([^/\s]*)" +                           # product token
      "(/([^\s]*))?" +                        # optional version
      "([\s]*\\[[a-zA-Z][a-zA-Z]\\])?" +      # optional old netscape
      "[\s]*" +                               # eat space!
      "(\\((([^()]|(\\([^()]*\\)))*)\\))?" +  # optional comment, allow one deep nested ()
      "[\s]*"                                 # eat space!
    )
    @products = @user_agent.scan(pattern).map{|match|
      [match[0], match[2], match[5]]
    }.select{|product| !product[0].empty?}
  end
  
  # Browser Identification
  
  def identify_browser
    identify_browser_opera or
    identify_browser_safari or
    identify_browser_honest or
    identify_browser_compatible or
    identify_browser_mozilla or
    identify_browser_other
  end
  
  def identify_browser_opera
    return unless @user_agent =~ /Opera/
    
    if opera = @products.detect{|product| product[0] == 'Opera'}
      if opera[1].nil?
        if @products[-2][0] == 'Opera'
          @browser_version = @products[-1][0]
        end
      else
        @browser_version = opera[1]
      end
      @browser_name = "Opera"
    end
  end
  
  def identify_browser_safari
    return unless @user_agent =~ /Safari|iPhone/
    
    if version = @products.detect{|product| product[0] == 'Version'}
      @browser_version = version[1]
    elsif browser = @products.detect{|product| product[0] == 'Safari'}
      @browser_version = browser[1]
    end
    @browser_name = 'Safari'
  end
  
  def identify_browser_honest
    honest_browsers = %w(Firefox Netscape Camino Mosaic Galeon)
    if browser = @products.detect{|product| honest_browsers.include? product[0]}
      @browser_version = browser[1]
      @browser_name = browser[0]
    end
  end
  
  def identify_browser_compatible
    compatible = /^compatible; ([^\s]+) ([^\s;]+)/
    if browser = @products.detect{|product| product[0] == 'Mozilla' && product[2] =~ compatible}
      # TODO? check_for_cloaked_products(AVANT_BROWSER, CRAZY_BROWSER);
      @browser_version = $2
      @browser_name = $1
    end
  end
  
  def identify_browser_mozilla
    first = @products.first
    if first[0] == 'Mozilla'
      if first[1].to_f < 5.0
        @browser_version = first[1]
        @browser_name = 'Netscape'
      else
        first[2] =~ /rv:([^s]+)/
        @browser_version = $1
        @browser_name = first[0]
      end
    end
  end
  
  def identify_browser_other
    @browser_version = @products.first[1]
    @browser_name = @products.first[0]
  end
  
  # OS Identification
  
  def identify_os
    @comment_elements = @products[0][2].split(/\s*;\s*/) rescue []
    identify_os_windows or
    identify_os_mac or
    identify_os_linux or
    identify_os_other
  end
  
  def identify_os_windows
    return unless element = @comment_elements.detect{|e| e =~ /^win.*\d/i}
    @os_name = 'Windows'
    @os_version = case element
    when /98/: '98'
    when /9x 4.90/: 'ME'
    when /NT 4.0/: 'NT'
    when /NT 5.0/: '2000'
    when /NT 5.1/: 'XP'
    when /NT 6.0/: 'Vista'
    end
  end
  
  def identify_os_mac
    return unless element = @comment_elements.detect{|e| e =~ /Mac OS X/} or
                  element = @comment_elements.detect{|e| e =~ /Macintosh/}
    @os_name = case element
    when /iphone/i
      'iPhone'
    else
      'Mac OS X'
    end
    
    if element =~ /(10_._.)/
      @os_version = $1.gsub('_','.')
    end
  end
  
  def identify_os_linux
    return unless element = @comment_elements.detect{|e| e =~ /linux/i}
    @os_name = 'Linux'
  end
  
  def identify_os_other
    %w(FreeBSD NetBSD OpenBSD SunOS Amiga BeOS IRIX OS/2 Warp).each do |os|
      os_regexp = Regexp.new(Regexp.escape(os))
      if @comment_elements.detect{|e| e =~ os_regexp}
        @os_name = os
        return
      end
    end
  end
end

module ForwardAWSUtil
  
  def self.filtertag(tag,add_prefix=nil,remove_prefix=nil)
    # Remove Prefix First
    if remove_prefix && tag
      tag = tag.sub(/^#{Regexp.escape(remove_prefix)}\b\.?/,"")
    end
    
    # Add Prefix
    if add_prefix
      if tag && tag.length > 0 
        tag = "#{add_prefix}.#{tag}"
      else
        tag = add_prefix
      end
    end
    
    # Return Result
    return tag
  end
  
end
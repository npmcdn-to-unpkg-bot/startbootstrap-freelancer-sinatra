require 'sinatra'
require 'pry'
require 'yaml'
require 'pony'
require 'json'
require 'mini_magick'
require 'fileutils'


set :session_secret, "328479283uf923fu8932fu923uf9832f23f232"
enable :sessions

module IndiceArray
  def self.set_site_nome site_nome
    @site_nome = site_nome       
  end
end

configure do
  # App Paths
  set :root, File.dirname(__FILE__)
  set :views, File.dirname(__FILE__) + '/views'
  set :public_folder, Proc.new { File.join(root, "public") }
end

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end

  def str_clean str
    str.to_s.gsub("<br>", "\n").gsub(/<\/?[^>]*>/, "").gsub("&nbsp;", "")
  end 
end

before do
  @logado = session[:logado]
  puts ">[@logado]>>#{@logado}"
  @data_path = "public/contas/{site_nome}/{site_nome}.yml"
end

#
# Encerra a seção de edição
#
get '/:site_nome/logout' do
  session.clear
  redirect '/'+params[:site_nome]
end

#
# Verificação de login
#
post '/login_do' do   

  # Pega os parâmetros 
  @post = params[:post]    
  site_nome = @post["site"]
  @form_senha = @post["senha"]
  @data_path.gsub! "{site_nome}", site_nome
  @data = YAML.load_file @data_path
  @data_senha = @data["senha"]
  
  #Compara a senha digitada no formulário de login com a senha do fonte
  if @form_senha.to_s == @data_senha.to_s then 
    session[:logado] = true
    session[:site_nome] = site_nome       
    @edit_flag = "true"
  else 
    session[:logado] = false
    session[:site_nome] = ""
    @edit_flag = "false"      
  end
  redirect '/'+site_nome
end

#
# Inicia o aplicativo
#
get '/:site_nome' do

  @site_nome = params[:site_nome]

  if @site_nome != "undefined" then 
    if @site_nome != "favicon.ico" then
      puts "[@site_nome]>#{@site_nome}"
      @edit_flag = session[:logado]
      if @edit_flag then
         if @site_nome == session[:site_nome] then    
            erb :index 
         else
           session.clear
           "<h1>Erro de autenticação (#{@edit_flag} - [#{@site_nome}] - [#{session[:site_nome]}])</h1>"
         end
      else
        erb :index 
      end       
    end
  end
end

#
# Lê os dados do arquivo fonte
#
get '/:site_nome/dataLoad' do 
  # Pega os dados do arquivo fonte
  site_nome = params[:site_nome]   
  @data_path.gsub! "{site_nome}", site_nome
  @data = YAML.load_file @data_path
  @data.to_json    
end

get '/:site_nome/logged' do 
  @edit_flag = session[:logado] || false
  "#{@edit_flag}"
end

#
# Pega os itens do portfólio
#
get '/:site_nome/getdata' do      
  data = YAML.load_file(@data_path) || {}
  data["pages"]["portfolio"]["items"].to_json
end

#
# Salva os dados do modo de edição
#
post '/:site_nome/objSave' do  
  
  # Pega os parâmetros
  site_nome = params[:site_nome] 
  @post_data = JSON.parse(request.body.read)  
  @obj = @post_data["obj"]  
  @val = @post_data["val"]
  @data_path.gsub! "{site_nome}", site_nome

  #Debug
  puts "@obj => #{@obj}"
  puts "@val => |#{@val}|"

  if @val == "" then @val = nil end

  # Autenticação
  if !@logado then redirect "/#{site_nome}" end

  # Lê o arquivo fonte
  data = YAML.load_file @data_path

  # Confere qual foi a ordem passada
  case @obj

    when "site.moldura.logo.label"
       data["moldura"]["logo"]["label"] = @val

    when "site.pages.home.label"
       data["pages"]["home"]["label"] = @val

    when "site.pages.home.body"
       data["pages"]["home"]["body"] = @val

    when "about.body1" 
       data["pages"]["about"]["body1"] = @val

    when "about.body2"
       data["pages"]["about"]["body2"] = @val

    when "site.moldura.footer.endereco"
       data["moldura"]["footer"]["endereco"] = @val

    when "site.moldura.footer.about_resumo"
       data["moldura"]["footer"]["about_resumo"] = @val

    when "site.pages.portfolio.label"
       data["pages"]["portfolio"]["label"] = @val
       data["moldura"]["menu"][0]["label"] = @val

    when "item.titulo"
       @item_n = @post_data["item_n"]
       data["pages"]["portfolio"]["items"][@item_n]["titulo"] = @val

    when "item.txt"
       @item_n = @post_data["item_n"]
       data["pages"]["portfolio"]["items"][@item_n]["txt"] = @val

    when "item.cliente"
       @item_n = @post_data["item_n"]
       data["pages"]["portfolio"]["items"][@item_n]["cliente"] = @val

    when "item.site"
       @item_n = @post_data["item_n"]
       data["pages"]["portfolio"]["items"][@item_n]["site"] = @val

    when "item.data"
       @item_n = @post_data["item_n"]
       data["pages"]["portfolio"]["items"][@item_n]["data"] = @val

    when "item.servico"
       @item_n = @post_data["item_n"]
       data["pages"]["portfolio"]["items"][@item_n]["servico"] = @val

    when "item.cat"
       @item_n = @post_data["item_n"]
       data["pages"]["portfolio"]["items"][@item_n]["cat"] = @val
       puts ">>item.cat<<"

    when "about.label"
       data["pages"]["about"]["label"] = @val
       data["moldura"]["menu"][1]["label"] = @val

    when "contact.label" then
       data["pages"]["contact"]["label"] = @val
       data["moldura"]["menu"][2]["label"] = @val
    
    # Footer / Social links
    when "site.moldura.footer.social.facebook" then
       data["moldura"]["footer"]["social"]["facebook"] = @val

    when "site.moldura.footer.social.googleplus" then
       puts "googleplus"
       data["moldura"]["footer"]["social"]["googleplus"] = @val

    when "site.moldura.footer.social.twitter" then
       data["moldura"]["footer"]["social"]["twitter"] = @val

    when "site.moldura.footer.social.linkedin" then
       data["moldura"]["footer"]["social"]["linkedin"] = @val
  end

  # Salva o arquivo base
  f = File.open(@data_path, 'w' )
  YAML.dump( data, f )
  f.close

end

#
# upload da imagem de capa (oval)
#
post "/:site_nome/avatar/upload" do 

  # Pega os parametros 
  site_nome = params[:site_nome]
  @filename = params[:file][:filename]
  file = params[:file][:tempfile]
  imagem_tipo = params[:file][:type]
  @data_path.gsub! "{site_nome}", site_nome

   # Autenticação
  if !@logado then redirect "/#{site_nome}" end

  # Testa para ver se é uma imagem que está sendo enviada
  if (imagem_tipo == 'image/png' || imagem_tipo == 'image/jpeg' || imagem_tipo == 'image/gif') && file.size < 5000000 then
    puts "file.size> #{file.size}"
    # Salva imagem no disco (upload)
    @filename = "avatar."+params["file"][:filename].split(".").last.downcase
    # @filename_after = "avatar.png"
    File.open("./public/contas/#{site_nome}/img/#{@filename}", 'wb') do |f|
      f.write(file.read)
    end
    
    # # Reduz o tamanho da imagem
    # image = MiniMagick::Image.open("./public/contas/#{site_nome}/img/#{@filename}")
    # image.resize "600x600"
    # image.format "png"   
    # image.write "./public/contas/#{site_nome}/img/#{@filename_after}"

    # Salva o nome da imagem o arquivo fonte
    data = YAML.load_file @data_path
    data["pages"]["home"]["img"] = "contas/#{site_nome}/img/#{@filename}"
    f = File.open(@data_path, 'w' )
    YAML.dump( data, f )
    f.close  
  end          
end

# 
#  portfolio: Excluindo um item
#
post "/:site_nome/portfolio/delete/:id" do 

  # Pega os parametros
  site_nome = params[:site_nome]
  @id = params[:id]
  @data_path.gsub! "{site_nome}", site_nome

  # Autenticação
  if !@logado then redirect "/#{site_nome}" end

  # Abre o arquivo fonte e exclui o item
  data = YAML.load_file @data_path
  data["pages"]["portfolio"]["items"].delete_at(@id.to_i)

  # Salva o arquivo com a alteração (exclusão)
  f = File.open(@data_path, 'w' )
  YAML.dump( data, f )
  f.close

  "Delete"
end

#
#  Portfolio: Mudança na ordenação
#
post "/:site_nome/portfolio/ordena" do

  # Pega os parâmetros
  site_nome = params[:site_nome]
  @post_data = JSON.parse(request.body.read)  
  @data_path.gsub! "{site_nome}", site_nome

  # Autenticação
  if !@logado then redirect "/#{site_nome}" end

  # Lê o arquivo fonte
  data = YAML.load_file @data_path
  data["pages"]["portfolio"]["items"] = @post_data  
  f = File.open(@data_path, 'w' )
  YAML.dump( data, f )
  f.close
end

#
#  Portfolio: upload da imagem do item
#
post "/:site_nome/portfolio/uploadPic/:index" do 

  # Pega os parâmetros
  @site_nome = params[:site_nome]
  @item = params[:item]
  @index = params[:index].to_i
  @file = params[:file]

  port_img = ""
  @data_path.gsub! "{site_nome}", @site_nome

  # Autenticação
  if !@logado then redirect "/#{@site_nome}" end

  # Carrega os dados do arquivo fonte
  data = YAML.load_file @data_path

  unless @file == nil
    @filename = params[:file][:filename]
    #@filename = Time.now.to_f.to_s+"."+params["file"][:filename].split(".").last.downcase

    puts "@filename> #{@filename}"
    file = params[:file][:tempfile]
    imagem_tipo = params[:file][:type]

    # Testa para ver se é uma imagem que está sendo enviada
    if (imagem_tipo == 'image/png' || imagem_tipo == 'image/jpeg' || imagem_tipo == 'image/gif') && file.size < 6000000 then
      img_path = "./public/contas/#{@site_nome}/img/portfolio/#{@filename}"
      File.open(img_path, 'wb') do |f|
        f.write(file.read)
      end

      #reduz a imagem
      image = MiniMagick::Image.open(img_path)
      image.resize "600x600"   
      image.write img_path
      port_img = "contas/#{@site_nome}/img/portfolio/#{@filename}"
    end
  end
  if (port_img == "" || port_img == "undefined" || port_img == nil) then port_img = @item["img"] end
  data["pages"]["portfolio"]["items"][@index]["img"] = port_img
  
  # Salva os dados alterados
  f = File.open(@data_path, 'w' )
  YAML.dump( data, f )
  f.close              
end

#
#  Portfolio: adicionando um novo item
#
post "/:site_nome/portfolio/add" do 

  # Pega os parâmetros
  @site_nome = params[:site_nome]
  @data_path.gsub! "{site_nome}", @site_nome

  # Autenticação
  if !@logado then redirect "/#{@site_nome}" end

  # Lê o arquivo base
  data = YAML.load_file @data_path

  # Prapara o novo item para inserção
  novo = { 
    "id"      => "",
    "titulo"  => "",
    "img"     => "/img/balao.jpg",
    "txt"     => "",
    "cliente" => "",
    "site"    => "",
    "data"    => "",
    "servico" => "",
    "cat"     => ""
  }

  # Insere o novo item na array do arquivo fonte
  data["pages"]["portfolio"]["items"] << novo

  # Salva o arquivo modificado
  f = File.open(@data_path, 'w' )
  YAML.dump( data, f )
  f.close
end

#
# Envia um email para o administrados com os dados digitados no formulário de contato
#
post '/email_envia' do

  # Pega os dados do formulário
  @site_nome = params[:site_nome]
  name = params[:name]
  email = params[:email]
  phone = params[:phone]
  message = params[:message]
  @data_path.gsub! "{site_nome}", @site_nome
  
  # Lê o arquivo base
  data = YAML.load_file @data_path

  @email_fonte = data["email"]
  

  # Debug
  # puts "site_nome:"+@site_nome
  # puts "Email:"+@email_fonte
  
  # # Envia o email
  # Pony.mail :to => data["email"],
  #           :from => email,
  #           :subject => "Contato",
  #           :body => message


  mailMassege = "Você recebeu um email de: #{name} / #{email} / #{phone}
                 #{message}"


  Pony.mail({
    :to => @email_fonte,
    :via => :smtp,
    :from => email,
    :subject => "Contato",
    :body => mailMassege,
    :via_options => {
      :address              => 'smtp.gmail.com',
      :port                 => '587',
      :enable_starttls_auto => true,
      :user_name            => 'contato@magaweb.com.br',
      :password             => 'maria108',
      :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
      :domain               => "localhost.magaweb.com.br" # the HELO domain provided by the client to the server
    }
  })
end

#
# Criar novo site
#
get "/novo_site_do/:email/:site_nome" do
  
  #Pega os parâmetros
  site_nome = params[:site_nome]
  email = params[:email]

  @data_path.gsub! "{site_nome}", site_nome
  #Cria diretorio principal
  install_dir = "public/contas/#{site_nome}"
  FileUtils::mkdir_p install_dir
  
  #Clona o arquivo base
  FileUtils.cp("site.yml", @data_path)
  
  #Cria diretorio de imagens
  install_dir = "public/contas/#{site_nome}/img/portfolio"
  FileUtils::mkdir_p install_dir

  #Define o nome/email no arquivo fonte
  data = YAML.load_file @data_path
  data["name"] = site_nome 
  data["email"] = email
  data["moldura"]["logo"]["label"] = site_nome 
  
  #Copia imagem da capa
  FileUtils.cp("public/img/balao.jpg","public/contas/#{site_nome}/img/balao.jpg")
  
  #Define a capa do site
  data["pages"]["home"]["img"] = "contas/#{site_nome}/img/balao.jpg"
  
  #Salva o arquivo fonte
  f = File.open(@data_path, 'w' )
  YAML.dump( data, f )
  f.close  
  
  session[:site_nome] = site_nome
  session[:login] = true

  # Abre o site recem criado no modo de edição
  redirect "/#{site_nome}"
end

#
#  Pedir novo site 
#
get "/novo_site/:userEmail/:site_nome" do 

  #Pega os parâmetros
  site_nome = params[:site_nome]
  userEmail = params[:userEmail]
  @data_path.gsub! "{site_nome}", site_nome

  #Envia email de confirmação da abertura da nova conta
  mailMassege = 
    "Este é um email de confirmação da abertura de sua nova conta.

     Dados de acesso:
     URL: magaweb.com.br/#{site_nome}
     Senha: 12345

     Clique no link de confirmação abaixo ou cole o endereço no seu browser:
     http://localhost:3000/novo_site_do/#{userEmail}/#{site_nome}

     Qualquer dúvida entre em contato conosco.
     
     Um abraço,
     Equipe Magaweb
     magaweb.com.br"
  
  Pony.mail({
    :to => userEmail,
    :via => :smtp,
    :from => "contato@magaweb.com.br",
    :subject => "Bem vindo!",
    :body => mailMassege,
    :via_options => {
      :address              => 'smtp.gmail.com',
      :port                 => '587',
      :enable_starttls_auto => true,
      :user_name            => 'contato@magaweb.com.br',
      :password             => 'maria108',
      :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
      :domain               => "localhost.magaweb.com.br" # the HELO domain provided by the client to the server
    }
  })

  # Abre o site recem criado no modo de edição
  "Um email de confirmação foi enviado para #{userEmail}"
end
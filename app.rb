require 'sinatra'
require 'active_record'
require 'sinatra/flash'
require_relative './app/models/member'
require_relative './app/models/post'
require_relative './app/models/friendship'
require_relative './app/models/likedpost'
require_relative './app/models/comment'
require_relative './app/models/notification'


ActiveRecord::Base.establish_connection(adapter: 'postgresql', database: 'shamango')

enable :sessions

def create_notification(member_id, message)
 Notification.create(member_id: member_id,
  notification_message: message)
end

get '/' do
  if session[:logged_in_user_id]
    erb :index
  else
    erb :login
  end
end

post '/' do
  session[:password_wrong] = false
  @member = Member.find_by email: params[:email]
  if @member.password == params[:password]
    session[:logged_in_user_id] = @member.id
    redirect '/'
  else
    session[:password_wrong] = true
    redirect '/'
  end
end

get '/new' do
  erb :create_user
end

post '/new' do
  member = Member.create params
  session[:logged_in_user_id] = member.id
  redirect '/'
end

get '/logout' do
  session.clear
  redirect '/'
end

get '/delete_account' do
  @dont_show_search = true
  erb :delete
end

post '/delete_account' do
  session[:password_wrong] = false
  @member = Member.find_by email: params[:email]
  if @member.password == params[:password]
    @member.destroy
    Post.where(member_id: @member.id).destroy_all
    session.clear
    redirect '/'
  else
    session[:password_wrong] = true
    redirect '/delete_account'
  end
end

post '/add_comment/home' do
  Comment.create params
  redirect '/'
end

post '/add_comment' do
  Comment.create post_id: params[:post_id],
                 contents: params[:contents]
  page_owner = Member.find_by_id(params[:page_owner].to_i)
  redirect "/#{page_owner.first_name.split.join}_#{page_owner.last_name}"
end

post '/search' do
  names_split = params[:name].split(" ")
  if names_split.length > 2
    first_name = "#{names_split[0]} #{names_split[1]}"
  else
    first_name = names_split[0]
  end
  @first_name_matches = []

  concat_name = params[:name].split.join.downcase
  Member.find_each do |member|
    if member.name.downcase == concat_name
      redirect "/#{member.first_name.split.join}_#{member.last_name}"
    elsif member.first_name.downcase == first_name.downcase
      @first_name_matches << member
    end
  end

  if @first_name_matches.empty?
    flash[:notice] = "the person you searched for didn't exist" 
  else 
    flash[:notice] = "here are suggestions:"
  end
  erb :search 
end


post '/add_friend' do
  Friendship.create(:member_id_one => params[:member_id_one],
   :member_id_two => params[:member_id_two],
   :accepted => false)
  create_notification(params[:member_id_two],"You have a pending friend request from: #{(Member.find_by_id(params[:member_id_one]).first_name)} #{(Member.find_by_id(params[:member_id_one]).last_name)}.")
  member_from_last_page = Member.find_by_id(params[:member_id_two])
  redirect "/#{member_from_last_page.first_name.split.join}_#{member_from_last_page.last_name}"
end

post '/confirm_friend' do
  page_owner = Member.find(params[:page_owner_id].to_i)
  if params[:different] == "true"
    request_to_accept = Friendship.where(member_id_one: params[:page_owner_id].to_i, member_id_two: params[:curr_user_id].to_i).take
    request_to_accept.accepted = true
    request_to_accept.save
    create_notification(request_to_accept.member_id_one,"You are now friends with: #{(Member.find_by_id(request_to_accept.member_id_two).first_name)} #{(Member.find_by_id(request_to_accept.member_id_two).last_name)}!")
    create_notification(request_to_accept.member_id_two,"You are now friends with: #{(Member.find_by_id(request_to_accept.member_id_one).first_name)} #{(Member.find_by_id(request_to_accept.member_id_one).last_name)}!")
  else
    request_to_accept = Friendship.find(params[:request_id].to_i)
    request_to_accept.accepted = true
    request_to_accept.save
    create_notification(request_to_accept.member_id_one,"You are now friends with: #{(Member.find_by_id(request_to_accept.member_id_two).first_name)} #{(Member.find_by_id(request_to_accept.member_id_two).last_name)}!")
    create_notification(request_to_accept.member_id_two,"You are now friends with: #{(Member.find_by_id(request_to_accept.member_id_one).first_name)} #{(Member.find_by_id(request_to_accept.member_id_one).last_name)}!")
  end

  redirect "/#{page_owner.first_name.split.join}_#{page_owner.last_name}"
end

post '/likepost' do
  post = Post.find_by_id(params[:post_id].to_i)
  member = Member.find_by_id(params[:member_id].to_i)
  Likedpost.create member_id: member.id,
                   post_id: post.id
  page_owner = Member.find_by_id(params[:page_owner].to_i)
  create_notification(post.member.id, "#{member.first_name} #{member.last_name} has liked your post: #{post.contents}")
  redirect "/#{page_owner.first_name.split.join}_#{page_owner.last_name}"
end

post '/deletepost' do
  post = Post.find_by_id(params[:post_id].to_i)
  Post.find_by_id(post).destroy
  page_owner = Member.find_by_id(params[:page_owner].to_i)
  redirect "/#{page_owner.first_name.split.join}_#{page_owner.last_name}"
end


post '/likeposthome' do
  post = Post.find_by_id(params[:post_id].to_i)
  member = Member.find_by_id(params[:member_id].to_i)
  Likedpost.create member_id: member.id,
                   post_id: post.id
  page_owner = Member.find_by_id(params[:page_owner].to_i)
  create_notification(post.member.id, "#{member.first_name} #{member.last_name} has liked your post: #{post.contents}")
  redirect "/"
end

post '/deleteposthome' do
  post = Post.find_by_id(params[:post_id].to_i)
  Post.find_by_id(post).destroy
  page_owner = Member.find_by_id(params[:page_owner].to_i)
  redirect "/"
end

get '/:member' do
  Member.find_each do |member|
    if member.name == params[:member].split("_").join
      @page_owner = member
    end
  end
  erb :member
end

get '/:member/notifications' do
  puts params
  erb :show_notifications
end

post '/:member' do
  member = Member.find_by_id(session[:logged_in_user_id])
  Post.create contents: params[:contents],
              member_id: session[:logged_in_user_id],
              post_reciever: params[:reciever_id]
  page_owner = Member.find_by_id(params[:page_owner].to_i)
  redirect "/#{page_owner.first_name.split.join}_#{page_owner.last_name}"
end

post '/:member/home' do
  member = Member.find_by_id(session[:logged_in_user_id])
  Post.create contents: params[:contents],
              member_id: session[:logged_in_user_id],
              post_reciever: params[:reciever_id]
  page_owner = Member.find_by_id(params[:page_owner].to_i)
  redirect "/"
end
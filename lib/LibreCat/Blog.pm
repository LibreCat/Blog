package LibreCat::Blog;
# Author: patrick.hochstenbach@ugent.be

use Catmandu -load;
use Dancer ':syntax';

our $VERSION = '0.1';
$Template::Stash::PRIVATE = undef;

hook 'before' => sub {
  if (! session('user') && request->path_info =~ m{^/(post|admin)}) {
      var requested_path => request->path_info;
      request->path_info('/login');
  }
};

# ---- Authentication
get '/login' => sub {
    template 'login';
};

post '/login' => sub {
    if (params->{password} eq 'letmein') {
        session user => params->{user};
        redirect params->{path} || '/';
    } else {
        redirect '/login?failed=1';
    }
};

get '/logout' => sub {
    session->destroy;
    redirect "/";
};

# ++++ Authentication


# ---- Blog pages
get '/' => sub {
    my $page_size = config->{page_size};
    my $hits  = Catmandu->store->bag->search(query => "draft:false" , limit => $page_size , sort => [{ unix_time => 'desc'}] );
    template 'index' , { posts => $hits->to_array , hits => $hits };
};

get '/page/:page' => sub {
    my $page_size = config->{page_size};
    my $page  = param('page'); 
    my $hits  = Catmandu->store->bag->search(query => "draft:false" , start => ($page - 1) * $page_size , limit => $page_size , sort => [{ unix_time => 'desc'}] );
    template 'index' , { posts => $hits->to_array , hits => $hits };
};

get '/story/:name' => sub {
    my $name = param('name'); 
    my $post = Catmandu->store->bag->get($name);
    template 'story' , { post => $post };
};

# ++++ Blog pages

# ---- Uploads
post '/upload' => sub {
    my $filename =  upload('upload')->filename;
    my $target   = config->{upload_dir} . "/" . $filename;
    upload('upload')->link_to($target); 
    config->{upload_link} . "/" . $filename;
};

# ++++ Uploads


# ---- Post messages

get '/post' => sub {
    my $date  = localtime time;
    my $id    = create_id();
    template 'post' , { id => $id , date => $date };
};

post '/post' => sub {
    my $id      = params->{id};
    my $draft   = params->{draft};
    my $title   = params->{title};
    my $message = params->{message};
    my $date    = params->{date};
    my $user    = session('user');
    my $tags    = comma_separated_list(params->{tags});

    Catmandu->store->bag->delete($id);
    Catmandu->store->bag->add( { _id => $id , draft => $draft , user => $user , title => $title , message => $message , tags => $tags , date => $date , unix_time => time });
    Catmandu->store->bag->commit;

    redirect "/";
};

post '/post/delete' => sub {
    my $id   = params->{id}; 
    my $post = Catmandu->store->bag->delete($id);
    Catmandu->store->bag->commit;
    redirect "/";
};


# ++++ Post messages

# ---- Helper functions

sub create_id() {
    return time . "-" . int(rand(9999));
}

sub comma_separated_list {
    return [] unless defined $_[0] && length $_[0];
    my (@arr) = map { s/^\s*|\s*$//; $_ } split(/\s*,\s*/,$_[0]);
    \@arr;
}

true;
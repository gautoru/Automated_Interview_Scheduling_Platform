from flask import Flask, render_template, request, redirect, url_for, flash
import mysql.connector

app = Flask(__name__)
app.secret_key = 'e2b3a8e9810f4b05a7ff3d64a9f4ea2a3f4a635ea2431b9c4d8e7d9c1f9d4b8c'  # for flash messaging

# Database connection
db_connection = mysql.connector.connect(
    host="localhost",
    user="root",
    password="Sripad123@",
    database="InterviewSchedulingPlatform"
)
cursor = db_connection.cursor()

# Route to the homepage
@app.route('/')
def home():
    return render_template('index.html')

# Add User route
@app.route('/add_user', methods=['POST'])
def add_user():
    name = request.form['name']
    email = request.form['email']
    role = request.form['role']
    password = request.form['password']
    contact_info = request.form['contact_info']

    if name and email and role and password:
        cursor.execute("INSERT INTO User (Name, Email, Role, Password, ContactInfo) VALUES (%s, %s, %s, %s, %s)",
                       (name, email, role, password, contact_info))
        db_connection.commit()
        flash('User added successfully!', 'success')
        return redirect(url_for('home', action='user_added'))
    else:
        flash('Please fill in all required fields.', 'error')
        return redirect(url_for('home'))

    

# Schedule Interview route
@app.route('/schedule_interview', methods=['POST'])
def schedule_interview():
    date = request.form['date']
    time = request.form['time']
    interview_type = request.form['interview_type']
    user_id = request.form['user_id']

    if date and time and interview_type and user_id:
        cursor.execute("INSERT INTO Interview (InterviewType, Status) VALUES (%s, %s)", (interview_type, 'scheduled'))
        interview_id = cursor.lastrowid

        cursor.execute("INSERT INTO Schedule (Date, Time, InterviewID, UserID) VALUES (%s, %s, %s, %s)",
                       (date, time, interview_id, user_id))
        db_connection.commit()
        flash('Interview scheduled successfully!', 'success')
        return redirect(url_for('home', action='interview_scheduled'))
    else:
        flash('Please fill in all required fields.', 'error')
        return redirect(url_for('home'))

    

# Fetch users for scheduling and display
@app.route('/get_users')
def get_users():
    cursor.execute("SELECT UserID, Name, Email, Role FROM User")
    users = cursor.fetchall()
    return render_template('schedule.html', users=users)

# Fetch scheduled interviews
@app.route('/get_scheduled_interviews')
def get_scheduled_interviews():
    cursor.execute('''
        SELECT s.ScheduleID, s.Date, s.Time, i.InterviewType, u.UserID, u.Name, i.Status
        FROM Schedule s
        JOIN Interview i ON s.InterviewID = i.InterviewID
        JOIN User u ON s.UserID = u.UserID
    ''')
    interviews = cursor.fetchall()
    return render_template('interviews.html', interviews=interviews)

# Delete user route
# Route for displaying the manage users page
@app.route('/manage_users')
def manage_users():
    cursor.execute("SELECT UserID, Name, Email, Role FROM User")
    users = cursor.fetchall()
    return render_template('manage_users.html', users=users)

# Route for deleting a user

@app.route('/delete_user/<int:user_id>', methods=['POST'])
def delete_user(user_id):
    try:
        cursor.execute("DELETE FROM User WHERE UserID = %s", (user_id,))
        db_connection.commit()
        return redirect(url_for('manage_users', action='user_deleted'))  # Redirect with action parameter
    except Exception as e:
        db_connection.rollback()
        flash("An error occurred while deleting the user.", 'error')
        print(e)
        return redirect(url_for('manage_users'))
    

# Route to render the update user form
@app.route('/update_user/<int:user_id>', methods=['GET'])
def update_user(user_id):
    cursor.execute("SELECT UserID, Name, Email, Role, ContactInfo FROM User WHERE UserID = %s", (user_id,))
    user = cursor.fetchone()
    if user:
        return render_template('update_user.html', user=user)
    else:
        flash('User not found.')
        return redirect(url_for('manage_users'))

# Route to handle the update user form submission
@app.route('/update_user/<int:user_id>', methods=['POST'])
def update_user_post(user_id):
    name = request.form['name']
    email = request.form['email']
    role = request.form['role']
    contact_info = request.form['contact_info']

    if name and email and role:
        cursor.execute(
            "UPDATE User SET Name = %s, Email = %s, Role = %s, ContactInfo = %s WHERE UserID = %s",
            (name, email, role, contact_info, user_id)
        )
        db_connection.commit()
        return redirect(url_for('manage_users', action='user_updated'))  # Redirect with action parameter
    else:
        flash('Please fill in all required fields.', 'error')
        return redirect(url_for('manage_users'))

    

@app.route('/delete_interview/<int:schedule_id>', methods=['POST'])
def delete_interview(schedule_id):
    try:
        cursor.execute("DELETE FROM Schedule WHERE ScheduleID = %s", (schedule_id,))
        db_connection.commit()
        return redirect(url_for('get_scheduled_interviews', action='interview_deleted'))
    except Exception as e:
        db_connection.rollback()
        flash("An error occurred while deleting the interview.", 'error')
        print(e)
        return redirect(url_for('get_scheduled_interviews'))

@app.route('/edit_interview/<int:schedule_id>', methods=['GET'])
def edit_interview(schedule_id):
    cursor.execute('''
        SELECT s.ScheduleID, s.Date, s.Time, i.InterviewType, u.UserID, u.Name
        FROM Schedule s
        JOIN Interview i ON s.InterviewID = i.InterviewID
        JOIN User u ON s.UserID = u.UserID
        WHERE s.ScheduleID = %s
    ''', (schedule_id,))
    interview = cursor.fetchone()

    # Fetch users to populate the user dropdown
    cursor.execute("SELECT UserID, Name FROM User")
    users = cursor.fetchall()

    if interview:
        return render_template('edit_interview.html', interview=interview, users=users)
    else:
        flash('Interview not found.')
        return redirect(url_for('get_scheduled_interviews'))

@app.route('/edit_interview/<int:schedule_id>', methods=['POST'])
def edit_interview_post(schedule_id):
    date = request.form['date']
    time = request.form['time']
    interview_type = request.form['interview_type']
    user_id = request.form['user_id']

    if date and time and interview_type and user_id:
        try:
            # Update the schedule
            cursor.execute('''
                UPDATE Schedule
                SET Date = %s, Time = %s, UserID = %s
                WHERE ScheduleID = %s
            ''', (date, time, user_id, schedule_id))

            # Update the interview type
            cursor.execute('''
                UPDATE Interview
                SET InterviewType = %s
                WHERE InterviewID = (
                    SELECT InterviewID FROM Schedule WHERE ScheduleID = %s
                )
            ''', (interview_type, schedule_id))

            db_connection.commit()
            return redirect(url_for('get_scheduled_interviews', action='interview_updated'))
        except Exception as e:
            db_connection.rollback()
            flash('An error occurred while updating the interview.', 'error')
            print(e)
    else:
        flash('Please fill in all required fields.', 'error')

    return redirect(url_for('get_scheduled_interviews'))



if __name__ == "__main__":
    app.run(debug=True)


